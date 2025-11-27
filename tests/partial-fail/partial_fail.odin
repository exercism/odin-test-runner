package partial_fail

import "core:fmt"

two_fer :: proc(name: string = "failure") -> string {
	return fmt.tprintf("One for {}, one for me.", name)
}

