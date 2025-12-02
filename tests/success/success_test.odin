package success

import "core:testing"

@(test)
/// description = No name given
test_no_name_given :: proc(t: ^testing.T) {
	testing.expect_value(t, two_fer(), "One for you, one for me.")
}

@(test)
/// description = A name given
test_a_name_given :: proc(t: ^testing.T) {
	testing.expect_value(t, two_fer("Alice"), "One for Alice, one for me.")
}

@(test)
// default description is the test proc name
test_another_name_given :: proc(t: ^testing.T) {
	testing.expect_value(t, two_fer("Bob"), "One for Bob, one for me.")
}
