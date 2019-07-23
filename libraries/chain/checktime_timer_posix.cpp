#include <eosio/chain/checktime_timer.hpp>
#include <eosio/chain/checktime_timer_accuracy.hpp>

#include <fc/time.hpp>
#include <fc/fwd_impl.hpp>
#include <fc/exception/exception.hpp>

#include <mutex>

#include <signal.h>
#include <time.h>

namespace eosio { namespace chain {

struct checktime_timer::impl {
   timer_t timerid;
   volatile sig_atomic_t* expired_ptr;
   std::vector<std::pair<void(*)(void*), void*>> callbacks;

   static void sig_handler(int, siginfo_t* si, void*) {
      checktime_timer::impl* me = (checktime_timer::impl*)si->si_value.sival_ptr;
      *me->expired_ptr = 1;

      for(size_t i = 0; i < me->callbacks.size(); ++i)
         me->callbacks[i].first(me->callbacks[i].second);
   }
};

checktime_timer::checktime_timer() {
   static_assert(sizeof(impl) <= fwd_size);

   static bool initialized;
   static std::mutex initalized_mutex;

   if(std::lock_guard guard(initalized_mutex); !initialized) {
      struct sigaction act;
      sigemptyset(&act.sa_mask);
      act.sa_sigaction = impl::sig_handler;
      act.sa_flags = SA_SIGINFO;
      FC_ASSERT(sigaction(SIGRTMIN, &act, NULL) == 0, "failed to aquire SIGRTMIN signal");
      initialized = true;
   }

   struct sigevent se;
   se.sigev_notify = SIGEV_SIGNAL;
   se.sigev_signo = SIGRTMIN;
   se.sigev_value.sival_ptr = (void*)&my;
   my->expired_ptr = &expired;

   FC_ASSERT(timer_create(CLOCK_REALTIME, &se, &my->timerid) == 0, "failed to create timer");

   compute_and_print_timer_accuracy(*this);
}

checktime_timer::~checktime_timer() {
   timer_delete(my->timerid);
}

void checktime_timer::add_expiry_callback(void(*func)(void*), void* user) {
   my->callbacks.emplace_back(func, user);
}

void checktime_timer::start(fc::time_point tp) {
   if(tp == fc::time_point::maximum()) {
      expired = 0;
      return;
   }
   fc::microseconds x = tp.time_since_epoch() - fc::time_point::now().time_since_epoch();
   if(x.count() <= 0)
      expired = 1;
   else {
      struct itimerspec enable = {{0, 0}, {0, (int)x.count()*1000}};
      expired = 0;
      if(timer_settime(my->timerid, 0, &enable, NULL) != 0)
         expired = 1;
   }
}

void checktime_timer::stop() {
   if(expired)
      return;
   struct itimerspec disable = {{0, 0}, {0, 0}};
   timer_settime(my->timerid, 0, &disable, NULL);
   expired = 1;
}

}}