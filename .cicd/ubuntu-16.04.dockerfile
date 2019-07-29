FROM ubuntu:16.04

# APT-GET dependencies.
RUN apt-get update && apt-get upgrade -y \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential git automake \
  libbz2-dev libssl-dev doxygen graphviz libgmp3-dev autotools-dev libicu-dev \
  python2.7 python2.7-dev python3 python3-dev autoconf libtool curl zlib1g-dev \
  sudo ruby libusb-1.0-0-dev libcurl4-gnutls-dev pkg-config

# Build appropriate version of CMake.
RUN curl -LO https://cmake.org/files/v3.13/cmake-3.13.2.tar.gz \
  && tar -xzf cmake-3.13.2.tar.gz \
  && cd cmake-3.13.2 \
  && ./bootstrap --prefix=/usr/local \
  && make -j$(nproc) \
  && make install \
  && cd .. \
  && rm -f cmake-3.13.2.tar.gz

# Build appropriate version of Clang.
RUN mkdir -p /root/tmp && cd /root/tmp && git clone --single-branch --branch release_80 https://git.llvm.org/git/llvm.git clang8             && cd clang8 && git checkout 18e41dc             && cd tools             && git clone --single-branch --branch release_80 https://git.llvm.org/git/lld.git             && cd lld && git checkout d60a035 && cd ../             && git clone --single-branch --branch release_80 https://git.llvm.org/git/polly.git             && cd polly && git checkout 1bc06e5 && cd ../             && git clone --single-branch --branch release_80 https://git.llvm.org/git/clang.git clang && cd clang             && git checkout a03da8b             && cd tools && mkdir extra && cd extra             && git clone --single-branch --branch release_80 https://git.llvm.org/git/clang-tools-extra.git             && cd clang-tools-extra && git checkout 6b34834 && cd ..             && cd ../../../../projects             && git clone --single-branch --branch release_80 https://git.llvm.org/git/libcxx.git             && cd libcxx && git checkout 1853712 && cd ../             && git clone --single-branch --branch release_80 https://git.llvm.org/git/libcxxabi.git             && cd libcxxabi && git checkout d7338a4 && cd ../             && git clone --single-branch --branch release_80 https://git.llvm.org/git/libunwind.git             && cd libunwind && git checkout 57f6739 && cd ../             && git clone --single-branch --branch release_80 https://git.llvm.org/git/compiler-rt.git             && cd compiler-rt && git checkout 5bc7979 && cd ../             && cd /root/tmp/clang8             && mkdir build && cd build             && cmake -G 'Unix Makefiles' -DCMAKE_INSTALL_PREFIX='/usr/local' -DLLVM_BUILD_EXTERNAL_COMPILER_RT=ON -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_ENABLE_LIBCXX=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_INCLUDE_DOCS=OFF -DLLVM_OPTIMIZED_TABLEGEN=ON -DLLVM_TARGETS_TO_BUILD=all -DCMAKE_BUILD_TYPE=Release ..             && make -j$(nproc)             && make install \
  && cd / && rm -rf /root/tmp/clang8

COPY ./pinned_toolchain.cmake /tmp/pinned_toolchain.cmake

# # Build appropriate version of LLVM.
RUN git clone --depth 1 --single-branch --branch release_40 https://github.com/llvm-mirror/llvm.git llvm \
  && cd llvm \
  && mkdir build \
  && cd build \
  && cmake -DLLVM_TARGETS_TO_BUILD=host -DLLVM_BUILD_TOOLS=false -DLLVM_ENABLE_RTTI=1 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_TOOLCHAIN_FILE='/tmp/pinned_toolchain.cmake' .. \
  && make -j$(nproc) \
  && make install \
  && cd /

# Build appropriate version of Boost.
RUN curl -LO https://dl.bintray.com/boostorg/release/1.70.0/source/boost_1_70_0.tar.bz2 \
  && tar -xjf boost_1_70_0.tar.bz2 \
  && cd boost_1_70_0 \
  && ./bootstrap.sh --with-toolset=clang --prefix=/usr/local \
  && ./b2 toolset=clang cxxflags='-stdlib=libc++ -D__STRICT_ANSI__ -nostdinc++ -I/usr/local/include/c++/v1' linkflags='-stdlib=libc++' link=static threading=multi --with-iostreams --with-date_time --with-filesystem --with-system --with-program_options --with-chrono --with-test -q -j$(nproc) install \
  && cd .. \
  && rm -f boost_1_70_0.tar.bz2    

# Build appropriate version of MongoDB.
RUN curl -LO http://downloads.mongodb.org/linux/mongodb-linux-x86_64-ubuntu1604-3.6.3.tgz \
  && tar -xzf mongodb-linux-x86_64-ubuntu1604-3.6.3.tgz \
  && rm -f mongodb-linux-x86_64-ubuntu1604-3.6.3.tgz

# Build appropriate version of MongoDB C Driver. 
RUN curl -LO https://github.com/mongodb/mongo-c-driver/releases/download/1.13.0/mongo-c-driver-1.13.0.tar.gz \
  && tar -xzf mongo-c-driver-1.13.0.tar.gz \
  && cd mongo-c-driver-1.13.0 \
  && mkdir -p build \
  && cd build \
  && cmake --DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DENABLE_BSON=ON -DENABLE_SSL=OPENSSL -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF -DENABLE_STATIC=ON -DCMAKE_TOOLCHAIN_FILE='/tmp/pinned_toolchain.cmake' .. \
  && make -j$(nproc) \
  && make install \
  && cd / \
  && rm -rf mongo-c-driver-1.13.0.tar.gz

# Build appropriate version of MongoDB C++ driver.
RUN curl -L https://github.com/mongodb/mongo-cxx-driver/archive/r3.4.0.tar.gz -o mongo-cxx-driver-r3.4.0.tar.gz \
  && tar -xzf mongo-cxx-driver-r3.4.0.tar.gz \
  && cd mongo-cxx-driver-r3.4.0 \
  && sed -i 's/\"maxAwaitTimeMS\", count/\"maxAwaitTimeMS\", static_cast<int64_t>(count)/' src/mongocxx/options/change_stream.cpp \
  && sed -i 's/add_subdirectory(test)//' src/mongocxx/CMakeLists.txt src/bsoncxx/CMakeLists.txt \
  && cd build \
  && cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_TOOLCHAIN_FILE='/tmp/pinned_toolchain.cmake' .. \
  && make -j$(nproc) \
  && make install \
  && cd / \
  && rm -f mongo-cxx-driver-r3.4.0.tar.gz

ENV PATH=${PATH}:/mongodb-linux-x86_64-ubuntu1604-3.6.3/bin

# Build appropriate version of ccache.
RUN curl -LO https://github.com/ccache/ccache/releases/download/v3.4.1/ccache-3.4.1.tar.gz \
  && tar -xzf ccache-3.4.1.tar.gz \
  && cd ccache-3.4.1 \
  && ./configure \
  && make \
  && make install \
  && cd / && rm -rf ccache-3.4.1/

# PRE_COMMANDS: Executed pre-cmake
# CMAKE_EXTRAS: Executed right before the cmake path (on the end)
ENV PRE_COMMANDS="export PATH=/usr/lib/ccache:$PATH &&"
ENV CMAKE_EXTRAS="$CMAKE_EXTRAS -DCMAKE_TOOLCHAIN_FILE='/tmp/pinned_toolchain.cmake' -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
ENV NPROC="$(nproc)"

CMD bash -c "$PRE_COMMANDS ccache -s && \
    export MAKE_PROC_LIMIT=${MAKE_PROC_LIMIT:-$NPROC} && \
    echo Building with -j$MAKE_PROC_LIMIT && \
    mkdir /workdir/build && cd /workdir/build && cmake -DCMAKE_BUILD_TYPE='Release' -DCORE_SYMBOL_NAME='SYS' -DOPENSSL_ROOT_DIR='/usr/include/openssl' -DBUILD_MONGO_DB_PLUGIN=true $CMAKE_EXTRAS /workdir && make -j$MAKE_PROC_LIMIT && \
    ctest -j$MAKE_PROC_LIMIT -LE _tests --output-on-failure -T Test"