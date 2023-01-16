yacc --yacc -d 1905109.y -o y.tab.cpp
echo 'y.tab.cpp and y.tab.hpp created'
flex -o 1905109.cpp 1905109.l
echo 'scanner created'
g++ -w *.cpp
echo 'a.out created'
rm 1905109.cpp y.tab.cpp y.tab.hpp
./a.out input.txt
rm a.out