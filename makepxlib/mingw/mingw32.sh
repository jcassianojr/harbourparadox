32bits
./configure --host=i686-w64-mingw32
make clean
make


mkdir build32 && cd build32
./configure --host=i686-w64-mingw32 --prefix=/c/devprg/pxlib32
make && make install
cd ..