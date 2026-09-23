; SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
; Copyright (C) 2026 SNAPKITTYWEST / Sovereign Kernel Project
; CLONE_GATE: icp-dag-crystallizer::mumps::icp_dag
;
; ICP-DAG v1.0 — MUMPS governance kernel
; Hierarchical globals: ^DAG("NODE",id), ^DAG("EDGE",from,to), ^DAG("SEAL")

ICPDAG ; Entry point
 N ID,TYPE,STATE,FROM,TO,ETYPE
 ;
 ; ── Node management ─────────────────────────────
 ;
ADDNODE(ID,TYPE,STATE) ;
 I '$$VALIDTYPE(TYPE) Q "ERR:INVALID_TYPE"
 I '$$VALIDSTATE(STATE) Q "ERR:INVALID_STATE"
 S ^DAG("NODE",ID,"TYPE")=TYPE
 S ^DAG("NODE",ID,"STATE")=STATE
 S ^DAG("NODE",ID,"TS")=$H
 Q "OK"
 ;
ADDEDGE(FROM,TO,ETYPE) ;
 I '$D(^DAG("NODE",FROM)) Q "ERR:I1_SRC_MISSING"
 I '$D(^DAG("NODE",TO)) Q "ERR:I1_TGT_MISSING"
 I FROM=TO Q "ERR:I2_SELF_EDGE"
 I $$REACHABLE(TO,FROM) Q "ERR:I10_CYCLE"
 S ^DAG("EDGE",FROM,TO)=ETYPE
 S ^DAG("EDGE",FROM,TO,"TS")=$H
 Q "OK"
 ;
 ; ── Invariant checks ────────────────────────────
 ;
CHECKI1() ;
 N F,T S F="" F  S F=$O(^DAG("EDGE",F)) Q:F=""  D
 . S T="" F  S T=$O(^DAG("EDGE",F,T)) Q:T=""  D
 . . I '$D(^DAG("NODE",F)) S ^DAG("VIOLATION","I1",F,T)="SRC"
 . . I '$D(^DAG("NODE",T)) S ^DAG("VIOLATION","I1",F,T)="TGT"
 Q
 ;
CHECKI2() ;
 N N1 S N1="" F  S N1=$O(^DAG("NODE",N1)) Q:N1=""  D
 . I $D(^DAG("EDGE",N1,N1)) S ^DAG("VIOLATION","I2",N1)=1
 Q
 ;
CHECKI3() ;
 N C,D S C="" F  S C=$O(^DAG("NODE",C)) Q:C=""  D
 . I ^DAG("NODE",C,"TYPE")="CLAIM",^DAG("NODE",C,"STATE")="unknown" D
 . . N D1 S D1="" F  S D1=$O(^DAG("EDGE",C,D1)) Q:D1=""  D
 . . . I ^DAG("EDGE",C,D1)="decides" S ^DAG("VIOLATION","I3",C,D1)=1
 Q
 ;
CHECKI5(D) ;
 N C S C="" F  S C=$O(^DAG("EDGE",C)) Q:C=""  D
 . I $D(^DAG("EDGE",C,D)),^DAG("EDGE",C,D)="decides" D
 . . I '$$PROVEN(C) S ^DAG("VIOLATION","I5",D,C)=1
 Q
 ;
CHECKALL() ;
 K ^DAG("VIOLATION")
 D CHECKI1(),CHECKI2(),CHECKI3()
 N D1 S D1="" F  S D1=$O(^DAG("NODE",D1)) Q:D1=""  D
 . I ^DAG("NODE",D1,"TYPE")="DECISION",^DAG("NODE",D1,"STATE")="authorized" D CHECKI5(D1)
 I '$D(^DAG("VIOLATION")) Q "VALID"
 Q "INVALID"
 ;
 ; ── Derived relations ───────────────────────────
 ;
PROVEN(C) ;
 N P S P="" F  S P=$O(^DAG("EDGE",C,P)) Q:P=""  D
 . I ^DAG("EDGE",C,P)="proven-by",^DAG("NODE",P,"STATE")="proven" Q 1
 Q 0
 ;
REACHABLE(X,Y) ;
 N V,Q,CUR,NEXT
 S Q(1)=X,V(X)=1
 N HEAD S HEAD=1,TAIL=1
 F  Q:HEAD>TAIL  D
 . S CUR=Q(HEAD),HEAD=HEAD+1
 . I CUR=Y Q 1
 . N N1 S N1="" F  S N1=$O(^DAG("EDGE",CUR,N1)) Q:N1=""  D
 . . I '$D(V(N1)) S TAIL=TAIL+1,Q(TAIL)=N1,V(N1)=1
 Q 0
 ;
 ; ── Seal ────────────────────────────────────────
 ;
SEAL() ;
 I $$CHECKALL()'="VALID" Q "ERR:GOVERNANCE_FAILED"
 N NC,EC S NC=0,EC=0
 N N1 S N1="" F  S N1=$O(^DAG("NODE",N1)) Q:N1=""  S NC=NC+1
 N F S F="" F  S F=$O(^DAG("EDGE",F)) Q:F=""  D
 . N T S T="" F  S T=$O(^DAG("EDGE",F,T)) Q:T=""  S EC=EC+1
 S ^DAG("SEAL")="SEALED"
 S ^DAG("SEAL","NODES")=NC
 S ^DAG("SEAL","EDGES")=EC
 S ^DAG("SEAL","TS")=$H
 Q "SEALED"
 ;
 ; ── Validators ──────────────────────────────────
 ;
VALIDTYPE(T) ;
 I T="EVIDENCE"!(T="CLAIM")!(T="CONSTRAINT")!(T="PROOF") Q 1
 I T="DECISION"!(T="AUTHORIZATION")!(T="EXECUTION") Q 1
 I T="AUDIT"!(T="POLICY") Q 1
 Q 0
 ;
VALIDSTATE(S) ;
 I S="unknown"!(S="proposed")!(S="verified")!(S="proven") Q 1
 I S="authorized"!(S="pending")!(S="executed") Q 1
 I S="contradicted"!(S="active")!(S="observed") Q 1
 Q 0
