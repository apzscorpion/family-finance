from datetime import datetime
from typing import List, Dict, Any
from sqlalchemy.orm import Session
from app.schemas.sync import OfflineMutation, SyncPushResult
from app.services.transaction_service import create_transaction, update_transaction_direct
from app.services.proposal_service import create_proposal

def process_push_mutations(db: Session, user_id: str, mutations: List[OfflineMutation]) -> List[SyncPushResult]:
    results = []

    for item in mutations:
        try:
            if item.entity_type == "TRANSACTION":
                if item.action == "CREATE":
                    txn = create_transaction(
                        db=db,
                        creator_id=user_id,
                        target_user_id=item.data.get("owner_id", user_id),
                        amount_cents=item.data["amount_cents"],
                        direction=item.data.get("direction", "EXPENSE"),
                        category=item.data.get("category", "Unclassified"),
                        source_id=item.data.get("source_id"),
                        organization_id=item.data.get("organization_id"),
                        description=item.data.get("description"),
                        merchant_or_payee=item.data.get("merchant_or_payee"),
                        payment_method=item.data.get("payment_method", "OTHER")
                    )
                    results.append(SyncPushResult(client_mutation_id=item.client_mutation_id, status="SUCCESS", server_id=txn.id))
                elif item.action == "UPDATE":
                    txn = update_transaction_direct(
                        db=db,
                        txn_id=item.data["id"],
                        editor_id=user_id,
                        updates=item.data,
                        expected_version=item.data.get("version")
                    )
                    results.append(SyncPushResult(client_mutation_id=item.client_mutation_id, status="SUCCESS", server_id=txn.id))

            elif item.entity_type == "PROPOSAL":
                prop = create_proposal(
                    db=db,
                    proposer_id=user_id,
                    target_user_id=item.data["target_user_id"],
                    proposal_type=item.data["proposal_type"],
                    proposed_data=item.data["proposed_data"],
                    target_transaction_id=item.data.get("target_transaction_id")
                )
                results.append(SyncPushResult(client_mutation_id=item.client_mutation_id, status="SUCCESS", server_id=prop.id))

        except Exception as e:
            results.append(SyncPushResult(
                client_mutation_id=item.client_mutation_id,
                status="ERROR",
                error_message=str(e)
            ))

    return results
