#!/usr/bin/env python3
"""Direct Python port of lisp.bas for verification.
Same algorithm, same variable names, same index conventions."""

class LispMachine:
    def __init__(self):
        self.AS = [''] * 70     # atom strings  (1-indexed)
        self.CH = [0] * 300     # car array      (1-indexed)
        self.CD = [0] * 300     # cdr array      (1-indexed)
        self.SK = [0] * 70      # stack: EA saves
        self.S1 = [0] * 70      # stack slot 1
        self.S2 = [0] * 70      # stack slot 2
        self.S3 = [0] * 70      # stack slot 3

        self.NA = self.NC = self.EA = self.SP = 0
        self.KN = self.KT = self.KQ = self.KC = 0
        self.KA = self.KE = self.KR = self.KD = self.KO = 0

        # Working variables (mirror BASIC globals)
        self.AX = self.RV = self.EV = self.ET = self.EF = self.EP = 0
        self.EE = self.EC = self.EM = self.EG = self.ES = 0
        self.RP = self.RH = self.RT = 0
        self.TK = ''
        self.IN = ''
        self.IX = 1
        self.AF = self.AA = 0
        self.SX = self.SA = 0
        self.PX = self.PY = self.PA = self.PN = self.PV = self.PP = 0
        self.RG = self.RS = 0
        self.CC = self.DD = 0
        self.PO = 0
        self.out = []
        self.error = False

    # ------------------------------------------------------------------
    # 1000  INTERN: TK$ -> AX%
    # ------------------------------------------------------------------
    def intern(self):
        for i in range(1, self.NA + 1):
            if self.AS[i] == self.TK:
                self.AX = i
                return
        self.NA += 1
        self.AS[self.NA] = self.TK
        self.AX = self.NA

    # ------------------------------------------------------------------
    # 2000  READ_EXPR: IN$,IX% -> RV%
    # ------------------------------------------------------------------
    def read_expr(self):
        # skip whitespace
        while self.IX <= len(self.IN) and self.IN[self.IX - 1] <= ' ':
            self.IX += 1
        if self.IX > len(self.IN):
            self.RV = self.KN
            return
        if self.IN[self.IX - 1] != '(':
            # collect atom token
            self.TK = ''
            while self.IX <= len(self.IN):
                c = self.IN[self.IX - 1]
                if c <= ' ' or c == '(' or c == ')':
                    break
                self.TK += c
                self.IX += 1
            if self.TK == '':
                self.RV = self.KN
                return
            self.intern()
            self.RV = self.AX
            return
        # list
        self.IX += 1
        self.read_list()

    # ------------------------------------------------------------------
    # 2100  READ_LIST: IN$,IX% -> RV%
    # ------------------------------------------------------------------
    def read_list(self):
        self.RH = 0
        self.RT = 0
        while True:
            while self.IX <= len(self.IN) and self.IN[self.IX - 1] <= ' ':
                self.IX += 1
            if self.IX > len(self.IN):
                self.RV = self.RH
                return
            if self.IN[self.IX - 1] == ')':
                self.IX += 1
                self.RV = self.RH
                return
            # save RH,RT; read next element; restore
            self.SP += 1
            self.S1[self.SP] = self.RH
            self.S2[self.SP] = self.RT
            self.read_expr()
            self.RP = self.RV
            self.RH = self.S1[self.SP]
            self.RT = self.S2[self.SP]
            self.SP -= 1
            # CONS_ALLOC(RP, 0)
            self.CC = self.RP
            self.DD = 0
            self.cons_alloc()
            if self.RH == 0:
                self.RH = self.RV
                self.RT = self.RV
            else:
                self.CD[-self.RT] = self.RV   # patch cdr of tail
                self.RT = self.RV

    # ------------------------------------------------------------------
    # 3000  EVAL: EE%,EA% -> EV%
    # ------------------------------------------------------------------
    def eval_expr(self):
        if self.EE == 0:
            self.EV = 0
            return
        if self.EE > 0:
            self.SX = self.EE
            self.SA = self.EA
            self.assoc()
            return
        car_ee = self.CH[-self.EE]
        if car_ee == self.KQ:
            self.EV = self.CH[-self.CD[-self.EE]]
            return
        if car_ee == self.KC:
            self.EC = self.CD[-self.EE]
            self.evcon()
            return
        # function application: save function before EVLIS clobbers EE
        self.EF = self.CH[-self.EE]
        self.EM = self.CD[-self.EE]
        self.evlis()
        self.AF = self.EF
        self.AX = self.EV    # AX% = evaluated arg list
        self.AA = self.EA
        self.apply_func()

    # ------------------------------------------------------------------
    # 3100  EVLIS: EM%,EA% -> EV%
    # ------------------------------------------------------------------
    def evlis(self):
        self.EG = 0
        self.ES = 0
        while True:
            if self.EM == 0:
                self.EV = self.EG
                return
            self.SP += 1
            self.S1[self.SP] = self.EM
            self.S2[self.SP] = self.EG
            self.S3[self.SP] = self.ES
            self.EE = self.CH[-self.EM]
            self.eval_expr()
            self.EP = self.EV
            self.EM = self.S1[self.SP]
            self.EG = self.S2[self.SP]
            self.ES = self.S3[self.SP]
            self.SP -= 1
            self.CC = self.EP
            self.DD = 0
            self.cons_alloc()
            if self.EG == 0:
                self.EG = self.RV
                self.ES = self.RV
            else:
                self.CD[-self.ES] = self.RV
                self.ES = self.RV
            self.EM = self.CD[-self.EM]

    # ------------------------------------------------------------------
    # 3200  EVCON: EC%,EA% -> EV%
    # ------------------------------------------------------------------
    def evcon(self):
        while True:
            if self.EC >= 0:
                self.out.append("?COND")
                self.SP = 0
                self.error = True
                return
            self.SP += 1
            self.S1[self.SP] = self.EC
            self.EE = self.CH[-self.CH[-self.EC]]   # Car(Car(EC))
            self.eval_expr()
            self.ET = self.EV
            self.EC = self.S1[self.SP]
            self.SP -= 1
            if self.ET != 0:
                self.EE = self.CH[-self.CD[-self.CH[-self.EC]]]  # Car(Cdr(Car(EC)))
                self.eval_expr()
                return
            self.EC = self.CD[-self.EC]

    # ------------------------------------------------------------------
    # 3300  APPLY: AF%,AX%,AA% -> EV%
    # ------------------------------------------------------------------
    def apply_func(self):
        if self.AF < 0:
            self.apply_lambda()
            return
        if self.AF == self.KO:
            self.CC = self.CH[-self.AX]
            self.DD = self.CH[-self.CD[-self.AX]]
            self.cons_alloc()
            self.EV = self.RV
            return
        if self.AF == self.KE:
            self.EV = self.KN
            if self.CH[-self.AX] == self.CH[-self.CD[-self.AX]]:
                self.EV = self.KT
            return
        if self.AF == self.KA:
            self.EV = self.KN
            if self.CH[-self.AX] >= 0:
                self.EV = self.KT
            return
        if self.AF == self.KR:
            self.EV = self.CH[-self.CH[-self.AX]]
            return
        if self.AF == self.KD:
            self.EV = self.CD[-self.CH[-self.AX]]
            return
        name = self.AS[self.AF] if 0 < self.AF <= self.NA else str(self.AF)
        self.out.append(f"?{name}")
        self.SP = 0
        self.error = True

    # ------------------------------------------------------------------
    # 3380  APPLY LAMBDA
    # ------------------------------------------------------------------
    def apply_lambda(self):
        self.PX = self.CH[-self.CD[-self.AF]]       # Car(Cdr(AF)) = params
        self.PY = self.AX
        self.PA = self.AA
        self.pairlis()
        self.SP += 1
        self.SK[self.SP] = self.EA
        self.EA = self.EV                            # new env from PAIRLIS
        self.EE = self.CH[-self.CD[-self.CD[-self.AF]]]  # Car(Cdr(Cdr(AF))) = body
        self.eval_expr()
        self.EA = self.SK[self.SP]
        self.SP -= 1

    # ------------------------------------------------------------------
    # 4000  ASSOC: SX%,SA% -> EV%
    # ------------------------------------------------------------------
    def assoc(self):
        sa = self.SA
        while True:
            if sa == 0:
                name = self.AS[self.SX] if 0 < self.SX <= self.NA else str(self.SX)
                self.out.append(f"?{name}")
                self.SP = 0
                self.error = True
                return
            if self.CH[-self.CH[-sa]] == self.SX:
                self.EV = self.CD[-self.CH[-sa]]
                return
            sa = self.CD[-sa]

    # ------------------------------------------------------------------
    # 4100  PAIRLIS: PX%,PY%,PA% -> EV%
    # ------------------------------------------------------------------
    def pairlis(self):
        self.RG = 0
        self.RS = 0
        px, py, pa = self.PX, self.PY, self.PA
        while px != 0:
            pn = self.CH[-px]
            pv = self.CH[-py]
            if pa != 0 and self.CH[-self.CH[-pa]] == pn:
                pa = self.CD[-pa]
            self.CC = pn
            self.DD = pv
            self.cons_alloc()
            pp = self.RV
            self.CC = pp
            self.DD = 0
            self.cons_alloc()
            if self.RG == 0:
                self.RG = self.RV
                self.RS = self.RV
            else:
                self.CD[-self.RS] = self.RV
                self.RS = self.RV
            px = self.CD[-px]
            py = self.CD[-py]
        if self.RS != 0:
            self.CD[-self.RS] = pa
        self.EV = self.RG if self.RG != 0 else pa

    # ------------------------------------------------------------------
    # 5000  PRINT_OBJ: PO%
    # ------------------------------------------------------------------
    def print_obj(self):
        if self.PO == 0:
            self.out.append("NIL")
            return
        if self.PO > 0:
            self.out.append(self.AS[self.PO])
            return
        self.out.append("(")
        self.SP += 1
        self.S1[self.SP] = self.PO
        self.PO = self.CH[-self.S1[self.SP]]
        self.print_obj()
        self.PO = self.CD[-self.S1[self.SP]]
        self.SP -= 1
        while self.PO != 0:
            if self.PO < 0:
                self.out.append(" ")
                self.SP += 1
                self.S1[self.SP] = self.PO
                self.PO = self.CH[-self.S1[self.SP]]
                self.print_obj()
                self.PO = self.CD[-self.S1[self.SP]]
                self.SP -= 1
            else:
                self.out.append(" . ")
                self.print_obj()
                self.out.append(")")
                return
        self.out.append(")")

    # ------------------------------------------------------------------
    # 6000  CONS_ALLOC: CC%,DD% -> RV%
    # ------------------------------------------------------------------
    def cons_alloc(self):
        if self.NC >= 256:
            raise RuntimeError("?HEAP FULL")
        self.NC += 1
        self.CH[self.NC] = self.CC
        self.CD[self.NC] = self.DD
        self.RV = -self.NC

    # ------------------------------------------------------------------
    # Lines 60-95: intern builtins
    # ------------------------------------------------------------------
    def startup(self):
        for name in ['NIL','T','QUOTE','COND','ATOM','EQ','CAR','CDR','CONS']:
            self.TK = name
            self.intern()
        (self.KN, self.KT, self.KQ, self.KC,
         self.KA, self.KE, self.KR, self.KD, self.KO) = range(1, 10)

    # ------------------------------------------------------------------
    # Run one REPL expression
    # ------------------------------------------------------------------
    def run(self, expr):
        self.IN = expr.upper()
        self.IX = 1
        self.SP = 0
        self.EA = 0
        self.out = []
        self.error = False
        self.read_expr()
        if self.error:
            return ''.join(self.out)
        self.EE = self.RV
        self.EA = 0
        self.eval_expr()
        if self.error:
            return ''.join(self.out)
        self.PO = self.EV
        self.print_obj()
        return ''.join(self.out)


TESTS = [
    ("(QUOTE A)",                                    "A"),
    ("(CAR (QUOTE (A B C)))",                        "A"),
    ("(CDR (QUOTE (A B C)))",                        "(B C)"),
    ("(ATOM (QUOTE A))",                             "T"),
    ("(ATOM (QUOTE (A B)))",                         "NIL"),
    ("(EQ (QUOTE A) (QUOTE A))",                     "T"),
    ("(CONS (QUOTE A) (QUOTE (B)))",                 "(A B)"),
    ("(COND ((ATOM (QUOTE A)) (QUOTE YES)))",        "YES"),
    ("((LAMBDA (X) (CAR X)) (QUOTE (A B)))",         "A"),
]

if __name__ == "__main__":
    passed = failed = 0
    for expr, expected in TESTS:
        m = LispMachine()
        m.startup()
        got = m.run(expr)
        ok = got == expected
        tag = "PASS" if ok else "FAIL"
        print(f"{tag}  {expr}")
        if not ok:
            print(f"      expected: {expected!r}")
            print(f"      got:      {got!r}")
        passed += ok
        failed += (not ok)
    print(f"\n{passed}/{passed+failed} passed")
