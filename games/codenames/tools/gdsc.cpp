// gdsc — Minimal GDScript-to-RISC-V ELF compiler CLI.
// Wraps the godot-sandbox GDScript compiler library.
//
// Usage:  gdsc <input.gd> <output.elf>
//         gdsc -          <output.elf>   (read from stdin)

#include "compiler.h"
#include <fstream>
#include <iostream>
#include <iterator>
#include <sstream>

int main(int argc, char** argv) {
	if (argc < 3) {
		std::cerr << "Usage: gdsc <input.gd> <output.elf>" << std::endl;
		return 1;
	}

	const std::string input_path = argv[1];
	const std::string output_path = argv[2];

	// Read source from file or stdin
	std::string source;
	if (input_path == "-") {
		source.assign(
			std::istreambuf_iterator<char>(std::cin),
			std::istreambuf_iterator<char>()
		);
	} else {
		std::ifstream in(input_path);
		if (!in.is_open()) {
			std::cerr << "Error: cannot open " << input_path << std::endl;
			return 1;
		}
		source.assign(
			std::istreambuf_iterator<char>(in),
			std::istreambuf_iterator<char>()
		);
	}

	if (source.empty()) {
		std::cerr << "Error: empty input" << std::endl;
		return 1;
	}

	gdscript::Compiler compiler;
	gdscript::CompilerOptions options;
	options.output_elf = true;

	if (!compiler.compile_to_file(source, output_path, options)) {
		std::cerr << "Compile error: " << compiler.get_error() << std::endl;
		return 1;
	}

	return 0;
}
