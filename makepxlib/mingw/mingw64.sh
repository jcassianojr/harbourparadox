
64bits
./configure --host=x86_64-w64-mingw32
make clean
make


mkdir build64 && cd build64
../configure --host=x86_64-w64-mingw32 --prefix=/c/devprg/pxlib64
make && make install
cd ..

