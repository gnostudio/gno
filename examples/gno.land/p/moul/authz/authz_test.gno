package authz

import (
	"errors"
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
)

func TestNew(t *testing.T) {
	testAddr := testutils.TestAddress("alice")
	testing.SetOriginCaller(testAddr)

	auth := New()

	// Check that the current authority is a MemberAuthority
	memberAuth, ok := auth.Current().(*MemberAuthority)
	uassert.True(t, ok, "expected MemberAuthority")

	// Check that the caller is a member
	uassert.True(t, memberAuth.Has(testAddr), "caller should be a member")

	// Check string representation
	expected := ufmt.Sprintf("member_authority[size=%d]", 1)
	uassert.Equal(t, expected, auth.String())
}

func TestNewWithAuthority(t *testing.T) {
	testAddr := testutils.TestAddress("alice")
	memberAuth := NewMemberAuthority(testAddr)

	auth := NewWithAuthority(memberAuth)

	// Check that the current authority is the one we provided
	uassert.True(t, auth.Current() == memberAuth, "expected provided authority")
}

func TestAuthorizerAuthorize(t *testing.T) {
	testAddr := testutils.TestAddress("alice")
	testing.SetOriginCaller(testAddr)

	auth := New()

	// Test successful action with args
	executed := false
	args := []any{"test_arg", 123}
	err := auth.Do("test_action", func() error {
		executed = true
		return nil
	}, args...)

	uassert.True(t, err == nil, "expected no error")
	uassert.True(t, executed, "action should have been executed")

	// Test unauthorized action with args
	testing.SetOriginCaller(testutils.TestAddress("bob"))

	executed = false
	err = auth.Do("test_action", func() error {
		executed = true
		return nil
	}, "unauthorized_arg")

	uassert.True(t, err != nil, "expected error")
	uassert.False(t, executed, "action should not have been executed")

	// Test action returning error
	testing.SetOriginCaller(testAddr)
	expectedErr := errors.New("test error")

	err = auth.Do("test_action", func() error {
		return expectedErr
	})

	uassert.True(t, err == expectedErr, "expected specific error")
}

func TestAuthorizerTransfer(t *testing.T) {
	testAddr := testutils.TestAddress("alice")
	testing.SetOriginCaller(testAddr)

	auth := New()

	// Test transfer to new member authority
	newAddr := testutils.TestAddress("bob")
	newAuth := NewMemberAuthority(newAddr)

	err := auth.Transfer(newAuth)
	uassert.True(t, err == nil, "expected no error")
	uassert.True(t, auth.Current() == newAuth, "expected new authority")

	// Test unauthorized transfer
	testing.SetOriginCaller(testutils.TestAddress("carol"))

	err = auth.Transfer(NewMemberAuthority(testAddr))
	uassert.True(t, err != nil, "expected error")

	// Test transfer to contract authority
	testing.SetOriginCaller(newAddr)

	contractAuth := NewContractAuthority("gno.land/r/test", func(title string, action PrivilegedAction) error {
		return action()
	})

	err = auth.Transfer(contractAuth)
	uassert.True(t, err == nil, "expected no error")
	uassert.True(t, auth.Current() == contractAuth, "expected contract authority")
}

func TestAuthorizerTransferChain(t *testing.T) {
	testAddr := testutils.TestAddress("alice")
	testing.SetOriginCaller(testAddr)

	// Create a chain of transfers
	auth := New()

	// First transfer to a new member authority
	newAddr := testutils.TestAddress("bob")
	memberAuth := NewMemberAuthority(newAddr)

	err := auth.Transfer(memberAuth)
	uassert.True(t, err == nil, "unexpected error in first transfer")

	// Then transfer to a contract authority
	contractAuth := NewContractAuthority("gno.land/r/test", func(title string, action PrivilegedAction) error {
		return action()
	})

	testing.SetOriginCaller(newAddr)
	err = auth.Transfer(contractAuth)
	uassert.True(t, err == nil, "unexpected error in second transfer")

	// Finally transfer to an auto-accept authority
	autoAuth := NewAutoAcceptAuthority()

	testing.SetOriginCaller(std.DerivePkgAddr("gno.land/r/test"))
	err = auth.Transfer(autoAuth)
	uassert.True(t, err == nil, "unexpected error in final transfer")
	uassert.True(t, auth.Current() == autoAuth, "expected auto-accept authority")
}

func TestAuthorizerWithDroppedAuthority(t *testing.T) {
	testAddr := testutils.TestAddress("alice")
	testing.SetOriginCaller(testAddr)

	auth := New()

	// Transfer to dropped authority
	err := auth.Transfer(NewDroppedAuthority())
	uassert.True(t, err == nil, "expected no error")

	// Try to execute action
	err = auth.Do("test_action", func() error {
		return nil
	})
	uassert.True(t, err != nil, "expected error from dropped authority")

	// Try to transfer again
	err = auth.Transfer(NewMemberAuthority(testAddr))
	uassert.True(t, err != nil, "expected error when transferring from dropped authority")
}

func TestContractAuthorityHandlerExecutionOnce(t *testing.T) {
	attempts := 0
	executed := 0

	contractAuth := NewContractAuthority("gno.land/r/test", func(title string, action PrivilegedAction) error {
		// Try to execute the action twice in the same handler
		if err := action(); err != nil {
			return err
		}
		attempts++

		// Second execution should fail
		if err := action(); err != nil {
			return err
		}
		attempts++
		return nil
	})

	// Set caller to contract address
	testing.SetOriginCaller(std.DerivePkgAddr("gno.land/r/test"))

	testArgs := []any{"proposal_id", 42, "metadata", map[string]string{"key": "value"}}
	err := contractAuth.Authorize("test_action", func() error {
		executed++
		return nil
	}, testArgs...)

	uassert.True(t, err == nil, "handler execution should succeed")
	uassert.True(t, attempts == 2, "handler should have attempted execution twice")
	uassert.True(t, executed == 1, "handler should have executed once")
}

func TestContractAuthorityExecutionTwice(t *testing.T) {
	executed := 0

	contractAuth := NewContractAuthority("gno.land/r/test", func(title string, action PrivilegedAction) error {
		return action()
	})

	// Set caller to contract address
	testing.SetOriginCaller(std.DerivePkgAddr("gno.land/r/test"))

	testArgs := []any{"proposal_id", 42, "metadata", map[string]string{"key": "value"}}

	err := contractAuth.Authorize("test_action", func() error {
		executed++
		return nil
	}, testArgs...)

	uassert.True(t, err == nil, "handler execution should succeed")
	uassert.True(t, executed == 1, "handler should have executed once")

	// A new action, even with the same title, should be executed
	err = contractAuth.Authorize("test_action", func() error {
		executed++
		return nil
	}, testArgs...)

	uassert.True(t, err == nil, "handler execution should succeed")
	uassert.True(t, executed == 2, "handler should have executed twice")
}

func TestContractAuthorityWithProposer(t *testing.T) {
	testAddr := testutils.TestAddress("alice")
	memberAuth := NewMemberAuthority(testAddr)

	handlerCalled := false
	actionExecuted := false

	contractAuth := NewRestrictedContractAuthority("gno.land/r/test", func(title string, action PrivilegedAction) error {
		handlerCalled = true
		// Set caller to contract address before executing action
		testing.SetOriginCaller(std.DerivePkgAddr("gno.land/r/test"))
		return action()
	}, memberAuth)

	// Test authorized member
	testing.SetOriginCaller(testAddr)
	testArgs := []any{"proposal_metadata", "test value"}
	err := contractAuth.Authorize("test_action", func() error {
		actionExecuted = true
		return nil
	}, testArgs...)

	uassert.True(t, err == nil, "authorized member should be able to propose")
	uassert.True(t, handlerCalled, "contract handler should be called")
	uassert.True(t, actionExecuted, "action should be executed")

	// Reset flags for unauthorized test
	handlerCalled = false
	actionExecuted = false

	// Test unauthorized proposer
	testing.SetOriginCaller(testutils.TestAddress("bob"))
	err = contractAuth.Authorize("test_action", func() error {
		actionExecuted = true
		return nil
	}, testArgs...)

	uassert.True(t, err != nil, "unauthorized member should not be able to propose")
	uassert.False(t, handlerCalled, "contract handler should not be called for unauthorized proposer")
	uassert.False(t, actionExecuted, "action should not be executed for unauthorized proposer")
}

func TestAutoAcceptAuthority(t *testing.T) {
	auth := NewAutoAcceptAuthority()

	// Test that any action is authorized
	executed := false
	err := auth.Authorize("test_action", func() error {
		executed = true
		return nil
	})

	uassert.True(t, err == nil, "auto-accept should not return error")
	uassert.True(t, executed, "action should have been executed")

	// Test with different caller
	testing.SetOriginCaller(testutils.TestAddress("random"))
	executed = false
	err = auth.Authorize("test_action", func() error {
		executed = true
		return nil
	})

	uassert.True(t, err == nil, "auto-accept should not care about caller")
	uassert.True(t, executed, "action should have been executed")
}

func TestAutoAcceptAuthorityWithArgs(t *testing.T) {
	auth := NewAutoAcceptAuthority()

	// Test that any action is authorized with args
	executed := false
	testArgs := []any{"arg1", 42, "arg3"}
	err := auth.Authorize("test_action", func() error {
		executed = true
		return nil
	}, testArgs...)

	uassert.True(t, err == nil, "auto-accept should not return error")
	uassert.True(t, executed, "action should have been executed")
}

func TestMemberAuthorityMultipleMembers(t *testing.T) {
	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")
	carol := testutils.TestAddress("carol")

	// Create authority with multiple members
	auth := NewMemberAuthority(alice, bob)

	// Test that both members can execute actions
	for _, member := range []std.Address{alice, bob} {
		testing.SetOriginCaller(member)
		err := auth.Authorize("test_action", func() error {
			return nil
		})
		uassert.True(t, err == nil, "member should be authorized")
	}

	// Test that non-member cannot execute
	testing.SetOriginCaller(carol)
	err := auth.Authorize("test_action", func() error {
		return nil
	})
	uassert.True(t, err != nil, "non-member should not be authorized")

	// Test Tree() functionality
	tree := auth.Tree()
	uassert.True(t, tree.Size() == 2, "tree should have 2 members")

	// Verify both members are in the tree
	found := make(map[std.Address]bool)
	tree.Iterate("", "", func(key string, _ any) bool {
		found[std.Address(key)] = true
		return false
	})
	uassert.True(t, found[alice], "alice should be in the tree")
	uassert.True(t, found[bob], "bob should be in the tree")
	uassert.False(t, found[carol], "carol should not be in the tree")

	// Test read-only nature of the tree
	defer func() {
		r := recover()
		uassert.True(t, r != nil, "modifying read-only tree should panic")
	}()
	tree.Set(string(carol), nil) // This should panic
}

func TestAuthorizerCurrentNeverNil(t *testing.T) {
	auth := New()

	// Current should never be nil after initialization
	uassert.True(t, auth.Current() != nil, "current authority should not be nil")

	// Current should not be nil after transfer
	err := auth.Transfer(NewAutoAcceptAuthority())
	uassert.True(t, err == nil, "transfer should succeed")
	uassert.True(t, auth.Current() != nil, "current authority should not be nil after transfer")
}

func TestAuthorizerString(t *testing.T) {
	auth := New()

	// Test initial string representation
	str := auth.String()
	uassert.True(t, str != "", "string representation should not be empty")

	// Test string after transfer
	autoAuth := NewAutoAcceptAuthority()
	err := auth.Transfer(autoAuth)
	uassert.True(t, err == nil, "transfer should succeed")

	newStr := auth.String()
	uassert.True(t, newStr != "", "string representation should not be empty")
	uassert.True(t, newStr != str, "string should change after transfer")
}

func TestContractAuthorityValidation(t *testing.T) {
	// Test empty path
	auth := NewContractAuthority("", nil)
	testing.SetOriginCaller(std.DerivePkgAddr(""))
	err := auth.Authorize("test", func() error {
		return nil
	})
	uassert.True(t, err != nil, "empty path authority should fail to authorize")

	// Test nil handler
	auth = NewContractAuthority("gno.land/r/test", nil)
	testing.SetOriginCaller(std.DerivePkgAddr("gno.land/r/test"))
	err = auth.Authorize("test", func() error {
		return nil
	})
	uassert.True(t, err != nil, "nil handler authority should fail to authorize")

	// Test valid configuration
	handler := func(title string, action PrivilegedAction) error {
		return nil
	}
	contractAuth := NewContractAuthority("gno.land/r/test", handler)
	testing.SetOriginCaller(std.DerivePkgAddr("gno.land/r/test"))
	err = contractAuth.Authorize("test", func() error {
		return nil
	})
	uassert.True(t, err == nil, "valid contract authority should authorize successfully")
}
