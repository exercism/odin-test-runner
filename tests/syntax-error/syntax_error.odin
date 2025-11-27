package syntax_error

import "core:fmt"

two_fer :: proc(name: string = "you") -> string {
	return "One for " + name + ", one for me."
}
