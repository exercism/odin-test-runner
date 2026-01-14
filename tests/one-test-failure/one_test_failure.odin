package one_test_failure

import "core:fmt"

two_fer :: proc(name: string = "failure") -> string {
	return fmt.tprintf("One for {}, one for me.", name)
}

