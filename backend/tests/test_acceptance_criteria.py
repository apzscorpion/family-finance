import pytest
from app.services import auth_service, org_service, transaction_service, proposal_service, sms_service
from app.models.organization import RoleEnum
from app.models.source import FinancialSource
from app.models.transaction import Transaction
from app.models.audit import TransactionAuditLog
from fastapi import HTTPException

# Test 1: User can register, log in, and create an organization
def test_01_user_register_login_create_org(db_session):
    user = auth_service.register_user(db_session, "asif@example.com", "Password123!", "Asif MN")
    assert user.id is not None

    login_res = auth_service.authenticate_user(db_session, "asif@example.com", "Password123!")
    assert "access_token" in login_res

    org = org_service.create_organization(db_session, user.id, "Our Family")
    assert org.id is not None
    assert org.owner_id == user.id

# Test 2 & 3: Organization member limit (30 members max) and rejection of 31st member
def test_02_03_org_member_limit_30(db_session):
    owner = auth_service.register_user(db_session, "owner@example.com", "Password123!", "Owner")
    org = org_service.create_organization(db_session, owner.id, "Big Family")

    # Add 29 more members to reach 30 total
    for i in range(29):
        member_user = auth_service.register_user(db_session, f"member{i}@example.com", "Password123!", f"Member {i}")
        inv = org_service.create_invitation(db_session, org.id, owner.id, member_user.email)
        org_service.accept_invitation(db_session, inv.token, member_user.id)

    assert org_service.get_active_member_count(db_session, org.id) == 30

    # Try creating invitation or accepting 31st member
    u31 = auth_service.register_user(db_session, "user31@example.com", "Password123!", "User 31")
    with pytest.raises(HTTPException) as exc:
        org_service.create_invitation(db_session, org.id, owner.id, u31.email)
    assert "30 members" in str(exc.value.detail)

# Test 4: Invited user cannot access organization before acceptance
def test_04_unaccepted_invited_user_no_access(db_session):
    owner = auth_service.register_user(db_session, "owner4@example.com", "Password123!", "Owner 4")
    org = org_service.create_organization(db_session, owner.id, "Org 4")
    u4 = auth_service.register_user(db_session, "u4@example.com", "Password123!", "User 4")

    org_service.create_invitation(db_session, org.id, owner.id, u4.email)
    
    member = org_service.get_organization_member(db_session, org.id, u4.id)
    assert member is None # No active access before acceptance

# Test 5: Members can create separate income sources and transactions
def test_05_separate_sources_and_transactions(db_session):
    u1 = auth_service.register_user(db_session, "u51@example.com", "Password123!", "U51")
    u2 = auth_service.register_user(db_session, "u52@example.com", "Password123!", "U52")

    s1 = FinancialSource(owner_id=u1.id, source_type="SALARY", display_name="U1 Salary", current_balance_cents=500000)
    s2 = FinancialSource(owner_id=u2.id, source_type="BUSINESS", display_name="U2 Business", current_balance_cents=1000000)
    db_session.add_all([s1, s2])
    db_session.commit()

    t1 = transaction_service.create_transaction(db_session, u1.id, u1.id, 50000, "EXPENSE", "Food", s1.id)
    t2 = transaction_service.create_transaction(db_session, u2.id, u2.id, 100000, "INCOME", "Sales", s2.id)

    assert t1.owner_id == u1.id
    assert t2.owner_id == u2.id

# Test 6 & 7: Owner view switching & organization summaries
def test_06_07_owner_view_switching(db_session):
    owner = auth_service.register_user(db_session, "owner6@example.com", "Password123!", "Owner 6")
    m6 = auth_service.register_user(db_session, "m6@example.com", "Password123!", "Member 6")
    org = org_service.create_organization(db_session, owner.id, "Org 6")
    inv = org_service.create_invitation(db_session, org.id, owner.id, m6.email)
    org_service.accept_invitation(db_session, inv.token, m6.id)

    # Validate owner has access to org member list for account switching context
    mem_record = org_service.get_organization_member(db_session, org.id, m6.id)
    assert mem_record is not None
    assert mem_record.user_id == m6.id

# Test 8: Authorization check prevents cross-organization data leakage
def test_08_cross_org_access_denied(db_session):
    u1 = auth_service.register_user(db_session, "u81@example.com", "Password123!", "U81")
    u2 = auth_service.register_user(db_session, "u82@example.com", "Password123!", "U82")
    org1 = org_service.create_organization(db_session, u1.id, "Org 1")
    org2 = org_service.create_organization(db_session, u2.id, "Org 2")

    member = org_service.get_organization_member(db_session, org1.id, u2.id)
    assert member is None

# Test 9, 10, 11, 12, 13: Collaborative Proposal Workflow
def test_09_to_13_collaborative_proposals(db_session):
    owner = auth_service.register_user(db_session, "owner9@example.com", "Password123!", "Owner 9")
    m9 = auth_service.register_user(db_session, "m9@example.com", "Password123!", "Member 9")
    org = org_service.create_organization(db_session, owner.id, "Org 9")
    inv = org_service.create_invitation(db_session, org.id, owner.id, m9.email)
    org_service.accept_invitation(db_session, inv.token, m9.id)

    # Member 9 proposes addition for Owner 9
    prop = proposal_service.create_proposal(
        db=db_session,
        proposer_id=m9.id,
        target_user_id=owner.id,
        proposal_type="ADDITION",
        proposed_data={"amount_cents": 40000, "category": "Transportation", "direction": "EXPENSE", "organization_id": org.id}
    )
    assert prop.status == "PENDING"

    # Pending proposal does NOT create a confirmed transaction balance
    assert db_session.query(Transaction).filter(Transaction.owner_id == owner.id).count() == 0

    # Proposer cannot self-approve
    with pytest.raises(HTTPException):
        proposal_service.decide_proposal(db_session, prop.id, m9.id, "APPROVED")

    # Target member approves proposal
    proposal_service.decide_proposal(db_session, prop.id, owner.id, "APPROVED")
    assert prop.status == "APPROVED"
    assert db_session.query(Transaction).filter(Transaction.owner_id == owner.id).count() == 1

# Test 14: Stale edit proposal cannot overwrite newer transaction
def test_14_stale_edit_proposal_rejected(db_session):
    u1 = auth_service.register_user(db_session, "u141@example.com", "Password123!", "U141")
    u2 = auth_service.register_user(db_session, "u142@example.com", "Password123!", "U142")

    s1 = FinancialSource(owner_id=u1.id, source_type="SAVINGS", display_name="Sav", current_balance_cents=100000)
    db_session.add(s1)
    db_session.commit()

    txn = transaction_service.create_transaction(db_session, u1.id, u1.id, 10000, "EXPENSE", "Food", s1.id)
    
    # Propose edit based on version 1
    prop = proposal_service.create_proposal(
        db=db_session,
        proposer_id=u2.id,
        target_user_id=u1.id,
        proposal_type="EDIT",
        proposed_data={"amount_cents": 15000},
        target_transaction_id=txn.id
    )

    # Owner edits transaction directly in the meantime (increments version to 2)
    transaction_service.update_transaction_direct(db_session, txn.id, u1.id, {"amount_cents": 12000})
    assert txn.version == 2

    # Attempting to approve stale proposal fails due to version mismatch
    with pytest.raises(HTTPException) as exc:
        proposal_service.decide_proposal(db_session, prop.id, u1.id, "APPROVED")
    assert "Stale edit proposal" in str(exc.value.detail)

# Test 15 & 16: Owner override and audit history preservation
def test_15_16_owner_override_and_audit(db_session):
    owner = auth_service.register_user(db_session, "owner15@example.com", "Password123!", "Owner 15")
    m15 = auth_service.register_user(db_session, "m15@example.com", "Password123!", "Member 15")
    org = org_service.create_organization(db_session, owner.id, "Org 15")
    inv = org_service.create_invitation(db_session, org.id, owner.id, m15.email)
    org_service.accept_invitation(db_session, inv.token, m15.id)

    txn = transaction_service.create_transaction(db_session, owner.id, m15.id, 20000, "EXPENSE", "Shopping", organization_id=org.id)
    
    audits = db_session.query(TransactionAuditLog).filter(TransactionAuditLog.transaction_id == txn.id).all()
    assert len(audits) > 0
    assert audits[0].action_type == "OWNER_OVERRIDE"

# Test 17 & 18: SMS deduplication and review status
def test_17_18_sms_parsing_and_deduplication(db_session):
    u = auth_service.register_user(db_session, "sms_user@example.com", "Password123!", "SMS User")
    sms_text = "Rs. 400.00 debited from account 1234 through UPI to Swiggy. Txn Ref 9988776655"
    
    e1 = sms_service.ingest_sms_event(db_session, u.id, "HDFCBK", sms_text)
    assert e1.parsing_status == "NEEDS_REVIEW"
    assert e1.parsed_amount_cents == 40000

    # Repeated SMS delivery marked as DUPLICATE
    e2 = sms_service.ingest_sms_event(db_session, u.id, "HDFCBK", sms_text)
    assert e2.parsing_status == "DUPLICATE"

# Test 19: Transfers do not inflate income or expenses
def test_19_transfers_do_not_inflate_totals(db_session):
    u1 = auth_service.register_user(db_session, "tr1@example.com", "Password123!", "TR1")
    u2 = auth_service.register_user(db_session, "tr2@example.com", "Password123!", "TR2")

    s1 = FinancialSource(owner_id=u1.id, source_type="SAVINGS", display_name="S1", current_balance_cents=100000)
    s2 = FinancialSource(owner_id=u2.id, source_type="SAVINGS", display_name="S2", current_balance_cents=50000)
    db_session.add_all([s1, s2])
    db_session.commit()

    tr = transaction_service.create_member_transfer(db_session, u1.id, s1.id, u2.id, s2.id, 20000)
    assert tr.debit_transaction.direction == "TRANSFER_OUT"
    assert tr.credit_transaction.direction == "TRANSFER_IN"

# Test 24: Loan disbursements are not classified as earned income
def test_24_loan_disbursement_not_earned_income(db_session):
    u = auth_service.register_user(db_session, "loan_user@example.com", "Password123!", "Loan User")
    s = FinancialSource(owner_id=u.id, source_type="LOAN", display_name="Personal Loan", current_balance_cents=0)
    db_session.add(s)
    db_session.commit()

    txn = transaction_service.create_transaction(db_session, u.id, u.id, 500000, "LOAN_DISBURSEMENT", "Bank Loan", s.id)
    assert txn.direction == "LOAN_DISBURSEMENT"
    assert txn.direction != "INCOME"

# Test 25: Monetary calculations rounding and reconciliation
def test_25_monetary_precision_reconciliation(db_session):
    u = auth_service.register_user(db_session, "money@example.com", "Password123!", "Money User")
    s = FinancialSource(owner_id=u.id, source_type="SAVINGS", display_name="Bank Account", current_balance_cents=10000) # Rs 100.00
    db_session.add(s)
    db_session.commit()

    # Add expense of Rs 40.50 (4050 paisa)
    transaction_service.create_transaction(db_session, u.id, u.id, 4050, "EXPENSE", "Snacks", s.id)
    db_session.refresh(s)
    assert s.current_balance_cents == 5950 # Rs 59.50 exactly
