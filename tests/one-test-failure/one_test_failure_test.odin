package one_test_failure

import "core:testing"

@(test)
/// description = No name given
/// task_id = 1
test_no_name_given :: proc(t: ^testing.T) {
	testing.expect_value(t, two_fer(), "One for you, one for me.")
}

