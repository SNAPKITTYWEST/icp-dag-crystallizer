// governance-validator.go - ICP-DAG Governance Protocol Implementation
// Validates agent communication against Integrity Constraint Protocol
// Min 600 LOC validation rules for I2, I3, I4, I5, I9, I10

package main

import (
	"encoding/json"
	"fmt"
	"sort"
	"sync"
	"time"
)

// ClaimState represents the verification state of a claim
type ClaimState string

const (
	Unknown      ClaimState = "Unknown"
	Verified     ClaimState = "Verified"
	Contradicted ClaimState = "Contradicted"
	Pending      ClaimState = "Pending"
)

// Claim represents an assertion made by an agent
type Claim struct {
	ID        string    `json:"id"`
	Agent     string    `json:"agent"`
	Content   string    `json:"content"`
	State     ClaimState `json:"state"`
	Timestamp uint64    `json:"timestamp"`
}

// Proof represents verification of claims forming a chain
type Proof struct {
	ClaimID       string   `json:"claim_id"`
	ProofChain    []string `json:"proof_chain"` // Ordered claim IDs
	VerifierAgent string   `json:"verifier_agent"`
	IsValid       bool     `json:"is_valid"`
}

// Decision represents consensus decision backed by proofs
type Decision struct {
	DecisionID        string   `json:"decision_id"`
	Agent             string   `json:"agent"`
	SupportingProofs  []string `json:"supporting_proofs"`
	ConflictingProofs []string `json:"conflicting_proofs"`
	Authorized        bool     `json:"authorized"`
	Timestamp         uint64   `json:"timestamp"`
}

// Execution represents action based on authorized decision
type Execution struct {
	ExecID     string `json:"exec_id"`
	Agent      string `json:"agent"`
	DecisionID string `json:"decision_id"`
	Executed   bool   `json:"executed"`
	Timestamp  uint64 `json:"timestamp"`
}

// AgentMessage represents inter-agent communication
type AgentMessage struct {
	Sender    string   `json:"sender"`
	Receiver  string   `json:"receiver"`
	Claim     Claim    `json:"claim"`
	MessageID string   `json:"message_id"`
	DependsOn []string `json:"depends_on"` // Message IDs this depends on
}

// ProtocolViolation records a rule violation
type ProtocolViolation struct {
	ViolationType  string `json:"violation_type"`
	Description    string `json:"description"`
	AffectedEntity string `json:"affected_entity"`
	RuleID         string `json:"rule_id"`
	Timestamp      uint64 `json:"timestamp"`
}

// DAGStructure represents agent dependency graph
type DAGStructure struct {
	Nodes            []string     `json:"nodes"`
	Edges            [][2]string  `json:"edges"`
	IsAcyclic        bool         `json:"is_acyclic"`
	Cycles           [][]string   `json:"cycles"`
	TopologicalSort  []string     `json:"topological_sort"`
}

// ClaimAnalysis summarizes claim states
type ClaimAnalysis struct {
	TotalClaims            int      `json:"total_claims"`
	VerifiedClaims         int      `json:"verified_claims"`
	UnknownClaims          int      `json:"unknown_claims"`
	ContradictedClaims     int      `json:"contradicted_claims"`
	PendingClaims          int      `json:"pending_claims"`
	StateInconsistencies   []string `json:"state_inconsistencies"`
}

// ExecutionChain traces execution to supporting claims
type ExecutionChain struct {
	ChainID       string   `json:"chain_id"`
	ExecutionID   string   `json:"execution_id"`
	DecisionID    string   `json:"decision_id"`
	Proofs        []string `json:"proofs"`
	Claims        []string `json:"claims"`
	IsValidChain  bool     `json:"is_valid_chain"`
	ChainLength   int      `json:"chain_length"`
}

// ValidationReport complete validation results
type ValidationReport struct {
	Violations       []ProtocolViolation `json:"violations"`
	IsValid          bool                `json:"is_valid"`
	DAGStructure     DAGStructure        `json:"dag_structure"`
	ClaimAnalysis    ClaimAnalysis       `json:"claim_analysis"`
	ExecutionChains  []ExecutionChain    `json:"execution_chains"`
	ValidationTime   string              `json:"validation_time"`
	ViolationSummary map[string]int      `json:"violation_summary"`
}

// ICPDAGValidator implements ICP-DAG validation logic
type ICPDAGValidator struct {
	claims     map[string]*Claim
	proofs     map[string]*Proof
	decisions  map[string]*Decision
	executions map[string]*Execution
	messages   []*AgentMessage
	violations []ProtocolViolation
	mu         sync.RWMutex
}

// NewICPDAGValidator creates validator instance
func NewICPDAGValidator() *ICPDAGValidator {
	return &ICPDAGValidator{
		claims:     make(map[string]*Claim),
		proofs:     make(map[string]*Proof),
		decisions:  make(map[string]*Decision),
		executions: make(map[string]*Execution),
		messages:   make([]*AgentMessage, 0),
		violations: make([]ProtocolViolation, 0),
	}
}

// RegisterClaim adds claim to validation system
func (v *ICPDAGValidator) RegisterClaim(claim *Claim) {
	v.mu.Lock()
	defer v.mu.Unlock()
	v.claims[claim.ID] = claim
}

// RegisterProof adds proof to validation system
func (v *ICPDAGValidator) RegisterProof(proof *Proof) {
	v.mu.Lock()
	defer v.mu.Unlock()
	v.proofs[proof.ClaimID] = proof
}

// RegisterDecision adds decision to validation system
func (v *ICPDAGValidator) RegisterDecision(decision *Decision) {
	v.mu.Lock()
	defer v.mu.Unlock()
	v.decisions[decision.DecisionID] = decision
}

// RegisterExecution adds execution to validation system
func (v *ICPDAGValidator) RegisterExecution(execution *Execution) {
	v.mu.Lock()
	defer v.mu.Unlock()
	v.executions[execution.ExecID] = execution
}

// RegisterMessage adds inter-agent message to validation system
func (v *ICPDAGValidator) RegisterMessage(message *AgentMessage) {
	v.mu.Lock()
	defer v.mu.Unlock()
	v.messages = append(v.messages, message)
}

// validateI3UnknownClaims - Rule I3: Unknown claims cannot authorize
func (v *ICPDAGValidator) validateI3UnknownClaims() {
	for decisionID, decision := range v.decisions {
		for _, proofID := range decision.SupportingProofs {
			if proof, exists := v.proofs[proofID]; exists {
				for _, claimID := range proof.ProofChain {
					if claim, exists := v.claims[claimID]; exists {
						if claim.State == Unknown {
							v.violations = append(v.violations, ProtocolViolation{
								ViolationType: "I3_VIOLATION",
								Description: fmt.Sprintf(
									"Unknown claim %s used in proof chain for decision %s",
									claimID, decisionID,
								),
								AffectedEntity: claimID,
								RuleID:         "I3",
								Timestamp:      uint64(time.Now().Unix()),
							})
						}
					}
				}
			}
		}
	}
}

// validateI4ContradictedClaims - Rule I4: Contradicted claims cannot authorize
func (v *ICPDAGValidator) validateI4ContradictedClaims() {
	for decisionID, decision := range v.decisions {
		// Check supporting proofs for contradicted claims
		for _, proofID := range decision.SupportingProofs {
			if proof, exists := v.proofs[proofID]; exists {
				for _, claimID := range proof.ProofChain {
					if claim, exists := v.claims[claimID]; exists {
						if claim.State == Contradicted {
							v.violations = append(v.violations, ProtocolViolation{
								ViolationType: "I4_VIOLATION",
								Description: fmt.Sprintf(
									"Contradicted claim %s used in proof for decision %s",
									claimID, decisionID,
								),
								AffectedEntity: claimID,
								RuleID:         "I4",
								Timestamp:      uint64(time.Now().Unix()),
							})
						}
					}
				}
			}
		}

		// Check for conflicting proofs alongside supporting proofs
		if len(decision.SupportingProofs) > 0 && len(decision.ConflictingProofs) > 0 {
			v.violations = append(v.violations, ProtocolViolation{
				ViolationType: "I4_VIOLATION",
				Description: fmt.Sprintf(
					"Decision %s has both supporting and conflicting proofs",
					decisionID,
				),
				AffectedEntity: decisionID,
				RuleID:         "I4",
				Timestamp:      uint64(time.Now().Unix()),
			})
		}
	}
}

// validateI5ExecutionChain - Rule I5: Execution needs authorized decision
func (v *ICPDAGValidator) validateI5ExecutionChain() {
	for execID, execution := range v.executions {
		if !execution.Executed {
			continue
		}

		decision, decisionExists := v.decisions[execution.DecisionID]
		if !decisionExists {
			v.violations = append(v.violations, ProtocolViolation{
				ViolationType: "I5_VIOLATION",
				Description: fmt.Sprintf(
					"Execution %s references non-existent decision %s",
					execID, execution.DecisionID,
				),
				AffectedEntity: execID,
				RuleID:         "I5",
				Timestamp:      uint64(time.Now().Unix()),
			})
			continue
		}

		if !decision.Authorized {
			v.violations = append(v.violations, ProtocolViolation{
				ViolationType: "I5_VIOLATION",
				Description: fmt.Sprintf(
					"Execution %s uses unauthorized decision %s",
					execID, execution.DecisionID,
				),
				AffectedEntity: execID,
				RuleID:         "I5",
				Timestamp:      uint64(time.Now().Unix()),
			})
			continue
		}

		// Verify all supporting proofs are valid
		for _, proofID := range decision.SupportingProofs {
			if proof, exists := v.proofs[proofID]; exists {
				if !proof.IsValid {
					v.violations = append(v.violations, ProtocolViolation{
						ViolationType: "I5_VIOLATION",
						Description: fmt.Sprintf(
							"Execution %s depends on invalid proof %s",
							execID, proofID,
						),
						AffectedEntity: execID,
						RuleID:         "I5",
						Timestamp:      uint64(time.Now().Unix()),
					})
				}

				// Verify claims in proof chain are verified
				for _, claimID := range proof.ProofChain {
					if claim, exists := v.claims[claimID]; exists {
						if claim.State != Verified {
							v.violations = append(v.violations, ProtocolViolation{
								ViolationType: "I5_VIOLATION",
								Description: fmt.Sprintf(
									"Execution %s depends on non-verified claim %s (state: %s)",
									execID, claimID, claim.State,
								),
								AffectedEntity: execID,
								RuleID:         "I5",
								Timestamp:      uint64(time.Now().Unix()),
							})
						}
					}
				}
			}
		}
	}
}

// validateI9ClaimConsistency - Rule I9: Claim state consistency
func (v *ICPDAGValidator) validateI9ClaimConsistency() ClaimAnalysis {
	analysis := ClaimAnalysis{
		TotalClaims:          len(v.claims),
		StateInconsistencies: make([]string, 0),
	}

	claimStateMap := make(map[string]map[ClaimState]bool)

	for claimID, claim := range v.claims {
		if _, exists := claimStateMap[claimID]; !exists {
			claimStateMap[claimID] = make(map[ClaimState]bool)
		}
		claimStateMap[claimID][claim.State] = true

		switch claim.State {
		case Verified:
			analysis.VerifiedClaims++
		case Unknown:
			analysis.UnknownClaims++
		case Contradicted:
			analysis.ContradictedClaims++
		case Pending:
			analysis.PendingClaims++
		}
	}

	// Check for state inconsistencies
	for claimID, states := range claimStateMap {
		hasUnknown := states[Unknown]
		hasVerified := states[Verified]
		hasContradicted := states[Contradicted]

		// Cannot be Unknown AND Verified
		if hasUnknown && hasVerified {
			analysis.StateInconsistencies = append(analysis.StateInconsistencies, claimID)
			v.violations = append(v.violations, ProtocolViolation{
				ViolationType: "I9_VIOLATION",
				Description: fmt.Sprintf(
					"Claim %s has simultaneous Unknown and Verified states",
					claimID,
				),
				AffectedEntity: claimID,
				RuleID:         "I9",
				Timestamp:      uint64(time.Now().Unix()),
			})
		}

		// Cannot be Verified AND Contradicted
		if hasVerified && hasContradicted {
			analysis.StateInconsistencies = append(analysis.StateInconsistencies, claimID)
			v.violations = append(v.violations, ProtocolViolation{
				ViolationType: "I9_VIOLATION",
				Description: fmt.Sprintf(
					"Claim %s has simultaneous Verified and Contradicted states",
					claimID,
				),
				AffectedEntity: claimID,
				RuleID:         "I9",
				Timestamp:      uint64(time.Now().Unix()),
			})
		}
	}

	return analysis
}

// validateAcyclicity - Rules I2 & I10: DAG acyclicity detection
func (v *ICPDAGValidator) validateAcyclicity() DAGStructure {
	dag := DAGStructure{
		Nodes: make([]string, 0),
		Edges: make([][2]string, 0),
		Cycles: make([][]string, 0),
	}

	// Build dependency graph from messages
	graph := make(map[string][]string)
	agents := make(map[string]bool)

	for _, msg := range v.messages {
		agents[msg.Sender] = true
		agents[msg.Receiver] = true

		graph[msg.Sender] = append(graph[msg.Sender], msg.Receiver)

		// Add message dependencies
		for _, depID := range msg.DependsOn {
			for _, depMsg := range v.messages {
				if depMsg.MessageID == depID {
					graph[depMsg.Sender] = append(graph[depMsg.Sender], msg.Sender)
				}
			}
		}
	}

	for agent := range agents {
		dag.Nodes = append(dag.Nodes, agent)
	}
	sort.Strings(dag.Nodes)

	for from, tos := range graph {
		for _, to := range tos {
			dag.Edges = append(dag.Edges, [2]string{from, to})
		}
	}

	// Detect cycles using DFS
	cycles := v.detectCyclesDFS(graph)
	dag.Cycles = cycles
	dag.IsAcyclic = len(cycles) == 0

	// Topological sort if acyclic
	if dag.IsAcyclic {
		dag.TopologicalSort = v.topologicalSort(graph)
	}

	return dag
}

// detectCyclesDFS detects cycles in directed graph
func (v *ICPDAGValidator) detectCyclesDFS(graph map[string][]string) [][]string {
	visited := make(map[string]int) // 0: unvisited, 1: visiting, 2: visited
	cycles := make([][]string, 0)
	path := make([]string, 0)

	var dfs func(node string)
	dfs = func(node string) {
		visited[node] = 1 // Mark as visiting
		path = append(path, node)

		if neighbors, exists := graph[node]; exists {
			for _, neighbor := range neighbors {
				if visited[neighbor] == 1 {
					// Back edge found - cycle detected
					cycleStart := -1
					for i, n := range path {
						if n == neighbor {
							cycleStart = i
							break
						}
					}
					if cycleStart != -1 {
						cycle := make([]string, len(path)-cycleStart)
						copy(cycle, path[cycleStart:])
						cycles = append(cycles, cycle)
					}
				} else if visited[neighbor] == 0 {
					dfs(neighbor)
				}
			}
		}

		path = path[:len(path)-1]
		visited[node] = 2 // Mark as visited
	}

	for node := range graph {
		if visited[node] == 0 {
			dfs(node)
		}
	}

	return cycles
}

// topologicalSort performs Kahn's algorithm
func (v *ICPDAGValidator) topologicalSort(graph map[string][]string) []string {
	inDegree := make(map[string]int)
	allNodes := make(map[string]bool)

	for from, tos := range graph {
		allNodes[from] = true
		if _, exists := inDegree[from]; !exists {
			inDegree[from] = 0
		}
		for _, to := range tos {
			allNodes[to] = true
			inDegree[to]++
		}
	}

	queue := make([]string, 0)
	for node := range allNodes {
		if inDegree[node] == 0 {
			queue = append(queue, node)
		}
	}

	result := make([]string, 0)
	for len(queue) > 0 {
		node := queue[0]
		queue = queue[1:]
		result = append(result, node)

		if neighbors, exists := graph[node]; exists {
			for _, neighbor := range neighbors {
				inDegree[neighbor]--
				if inDegree[neighbor] == 0 {
					queue = append(queue, neighbor)
				}
			}
		}
	}

	return result
}

// buildExecutionChains traces execution→decision→proof→claim chains
func (v *ICPDAGValidator) buildExecutionChains() []ExecutionChain {
	chains := make([]ExecutionChain, 0)

	for execID, execution := range v.executions {
		chain := ExecutionChain{
			ChainID:     fmt.Sprintf("chain_%s", execID),
			ExecutionID: execID,
			DecisionID:  execution.DecisionID,
			Proofs:      make([]string, 0),
			Claims:      make([]string, 0),
		}

		if decision, exists := v.decisions[execution.DecisionID]; exists {
			chain.Proofs = append(chain.Proofs, decision.SupportingProofs...)

			for _, proofID := range chain.Proofs {
				if proof, exists := v.proofs[proofID]; exists {
					chain.Claims = append(chain.Claims, proof.ProofChain...)
				}
			}

			// Validate chain
			chain.IsValidChain = decision.Authorized
			if chain.IsValidChain {
				for _, proofID := range chain.Proofs {
					if proof, exists := v.proofs[proofID]; exists && !proof.IsValid {
						chain.IsValidChain = false
						break
					}
				}
			}

			if chain.IsValidChain {
				for _, claimID := range chain.Claims {
					if claim, exists := v.claims[claimID]; exists && claim.State != Verified {
						chain.IsValidChain = false
						break
					}
				}
			}
		}

		chain.ChainLength = len(chain.Proofs) + len(chain.Claims)
		chains = append(chains, chain)
	}

	return chains
}

// Validate performs complete validation
func (v *ICPDAGValidator) Validate() ValidationReport {
	v.mu.Lock()
	v.violations = make([]ProtocolViolation, 0)
	v.mu.Unlock()

	// Run all validations
	v.validateI3UnknownClaims()
	v.validateI4ContradictedClaims()
	v.validateI5ExecutionChain()
	claimAnalysis := v.validateI9ClaimConsistency()
	dagStructure := v.validateAcyclicity()

	// Check acyclicity rules
	if !dagStructure.IsAcyclic {
		for _, cycle := range dagStructure.Cycles {
			cycleStr := fmt.Sprintf("%v", cycle)
			v.violations = append(v.violations, ProtocolViolation{
				ViolationType: "I2_I10_VIOLATION",
				Description:   fmt.Sprintf("Cycle detected in DAG: %s", cycleStr),
				AffectedEntity: cycleStr,
				RuleID:         "I2_I10",
				Timestamp:      uint64(time.Now().Unix()),
			})
		}
	}

	executionChains := v.buildExecutionChains()
	isValid := len(v.violations) == 0

	// Build violation summary
	violationSummary := make(map[string]int)
	for _, v := range v.violations {
		violationSummary[v.RuleID]++
	}

	return ValidationReport{
		Violations:       v.violations,
		IsValid:          isValid,
		DAGStructure:     dagStructure,
		ClaimAnalysis:    claimAnalysis,
		ExecutionChains:  executionChains,
		ValidationTime:   time.Now().Format(time.RFC3339),
		ViolationSummary: violationSummary,
	}
}

// String formats validation report for output
func (r ValidationReport) String() string {
	output := fmt.Sprintf("=== ICP-DAG Governance Protocol Validation Report ===\n\n")
	output += fmt.Sprintf("Overall Status: ")
	if r.IsValid {
		output += "VALID\n"
	} else {
		output += "INVALID\n"
	}
	output += fmt.Sprintf("Total Violations: %d\n", len(r.Violations))
	output += fmt.Sprintf("Validation Time: %s\n\n", r.ValidationTime)

	if len(r.Violations) > 0 {
		output += "--- Protocol Violations ---\n"
		for idx, v := range r.Violations {
			output += fmt.Sprintf("%d. [%s] %s\n", idx+1, v.RuleID, v.ViolationType)
			output += fmt.Sprintf("   Entity: %s\n", v.AffectedEntity)
			output += fmt.Sprintf("   Desc: %s\n\n", v.Description)
		}
	}

	output += fmt.Sprintf("--- Claim Analysis ---\n")
	output += fmt.Sprintf("Total Claims: %d\n", r.ClaimAnalysis.TotalClaims)
	output += fmt.Sprintf("Verified: %d\n", r.ClaimAnalysis.VerifiedClaims)
	output += fmt.Sprintf("Unknown: %d\n", r.ClaimAnalysis.UnknownClaims)
	output += fmt.Sprintf("Contradicted: %d\n", r.ClaimAnalysis.ContradictedClaims)
	output += fmt.Sprintf("State Inconsistencies: %d\n\n", len(r.ClaimAnalysis.StateInconsistencies))

	output += fmt.Sprintf("--- DAG Structure ---\n")
	output += fmt.Sprintf("Nodes: %d\n", len(r.DAGStructure.Nodes))
	output += fmt.Sprintf("Edges: %d\n", len(r.DAGStructure.Edges))
	output += fmt.Sprintf("Acyclic: %v\n", r.DAGStructure.IsAcyclic)
	if len(r.DAGStructure.Cycles) > 0 {
		output += fmt.Sprintf("Cycles Found: %d\n", len(r.DAGStructure.Cycles))
	}

	output += fmt.Sprintf("\n--- Execution Chains ---\n")
	output += fmt.Sprintf("Total Chains: %d\n", len(r.ExecutionChains))
	for _, chain := range r.ExecutionChains {
		output += fmt.Sprintf("  %s: %d proofs, %d claims, Valid: %v\n",
			chain.ChainID, len(chain.Proofs), len(chain.Claims), chain.IsValidChain)
	}

	return output
}

// JSON returns JSON representation of report
func (r ValidationReport) JSON() (string, error) {
	data, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// Example usage
func main() {
	validator := NewICPDAGValidator()

	// Example 1: Valid authorization chain
	verifiedClaim := &Claim{
		ID:        "claim_1",
		Agent:     "governance_board",
		Content:   "Policy approved",
		State:     Verified,
		Timestamp: 1000,
	}
	validator.RegisterClaim(verifiedClaim)

	proof := &Proof{
		ClaimID:       "proof_1",
		ProofChain:    []string{"claim_1"},
		VerifierAgent: "validator",
		IsValid:       true,
	}
	validator.RegisterProof(proof)

	decision := &Decision{
		DecisionID:        "dec_1",
		Agent:             "consensus",
		SupportingProofs:  []string{"proof_1"},
		ConflictingProofs: []string{},
		Authorized:        true,
		Timestamp:         1001,
	}
	validator.RegisterDecision(decision)

	execution := &Execution{
		ExecID:     "exec_1",
		Agent:      "executor",
		DecisionID: "dec_1",
		Executed:   true,
		Timestamp:  1002,
	}
	validator.RegisterExecution(execution)

	// Validate
	report := validator.Validate()
	fmt.Println(report.String())

	// JSON output
	jsonReport, _ := report.JSON()
	fmt.Println("\n" + jsonReport)
}
