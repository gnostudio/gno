package simpledao

import (
	"std"

	"gno.land/p/demo/membstore"
)

type executeDelegate func() error

type mockExecutor struct {
	executeFn executeDelegate
}

func (m *mockExecutor) Execute() error {
	if m.executeFn != nil {
		return m.executeFn()
	}

	return nil
}

type (
	membersDelegate      func(uint64, uint64) []membstore.Member
	sizeDelegate         func() int
	isMemberDelegate     func(std.Address) bool
	totalPowerDelegate   func() uint64
	memberDelegate       func(std.Address) (membstore.Member, error)
	addMemberDelegate    func(membstore.Member) error
	updateMemberDelegate func(std.Address, membstore.Member) error
)

type mockMemberStore struct {
	membersFn      membersDelegate
	sizeFn         sizeDelegate
	isMemberFn     isMemberDelegate
	totalPowerFn   totalPowerDelegate
	memberFn       memberDelegate
	addMemberFn    addMemberDelegate
	updateMemberFn updateMemberDelegate
}

func (m *mockMemberStore) Members(offset, count uint64) []membstore.Member {
	if m.membersFn != nil {
		return m.membersFn(offset, count)
	}

	return nil
}

func (m *mockMemberStore) Size() int {
	if m.sizeFn != nil {
		return m.sizeFn()
	}

	return 0
}

func (m *mockMemberStore) IsMember(address std.Address) bool {
	if m.isMemberFn != nil {
		return m.isMemberFn(address)
	}

	return false
}

func (m *mockMemberStore) TotalPower() uint64 {
	if m.totalPowerFn != nil {
		return m.totalPowerFn()
	}

	return 0
}

func (m *mockMemberStore) Member(address std.Address) (membstore.Member, error) {
	if m.memberFn != nil {
		return m.memberFn(address)
	}

	return membstore.Member{}, nil
}

func (m *mockMemberStore) AddMember(member membstore.Member) error {
	if m.addMemberFn != nil {
		return m.addMemberFn(member)
	}

	return nil
}

func (m *mockMemberStore) UpdateMember(address std.Address, member membstore.Member) error {
	if m.updateMemberFn != nil {
		return m.updateMemberFn(address, member)
	}

	return nil
}
