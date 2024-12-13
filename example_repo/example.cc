#include <ctime>
#include <string>
#include <iostream>

int main(int argc, char** argv) {
    std::time_t now = std::time(nullptr);
    std::string time = std::asctime(std::localtime(&now));
    time.pop_back();

    std::string who = "world";

    if (argc > 1) {
        who = argv[1];
    }

    std::cout << time << " -- Hello " << who << std::endl;

    return 0;
}
