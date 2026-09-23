/// ICP-DAG Governance Protocol Validator
/// Validates agent communication against Integrity Constraint Protocol rules
/// with Directed Acyclic Graph (DAG) consistency checking
///
/// Rules:
/// I2:  DAG acyclicity - no cycles in agent dependency graph
/// I3:  Unknown claims cannot authorize - unknown state prevents decision
/// I4:  Contradicted claims cannot authorize - conflicting proofs invalidate
/// I5:  Execution needs authorized decision - exec→decision→proof→claim chain
/// I9:  Claim state consistency - no simultaneous unknown+verified
/// I10: Reachability acyclicity - transitive dependencies must be acyclic

use std::collections::{HashMap, HashSet, VecDeque};
use std::fmt;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ClaimState {
    Unknown,
    Verified,
    Contradicted,
    Pending,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Claim {
    pub id: String,
    pub agent: String,
    pub content: String,
    pub state: ClaimState,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Proof {
    pub claim_id: String,
    pub proof_chain: Vec<String>, // chain of claims this proof depends on
    pub verifier_agent: String,
    pub is_valid: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Decision {
    pub decision_id: String,
    pub agent: String,
    pub supporting_proofs: Vec<String>,
    pub conflicting_proofs: Vec<String>,
    pub authorized: bool,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Execution {
    pub exec_id: String,
    pub agent: String,
    pub decision_id: String,
    pub executed: bool,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentMessage {
    pub sender: String,
    pub receiver: String,
    pub claim: Claim,
    pub message_id: String,
    pub depends_on: Vec<String>, // message IDs this depends on
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProtocolViolation {
    pub violation_type: String,
    pub description: String,
    pub affected_entity: String,
    pub rule_id: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ValidationReport {
    pub violations: Vec<ProtocolViolation>,
    pub is_valid: bool,
    pub dag_structure: DAGStructure,
    pub claim_analysis: ClaimAnalysis,
    pub execution_chains: Vec<ExecutionChain>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DAGStructure {
    pub nodes: Vec<String>,
    pub edges: Vec<(String, String)>,
    pub is_acyclic: bool,
    pub cycles: Vec<Vec<String>>,
    pub topological_sort: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ClaimAnalysis {
    pub total_claims: usize,
    pub unknown_claims: usize,
    pub verified_claims: usize,
    pub contradicted_claims: usize,
    pub state_inconsistencies: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ExecutionChain {
    pub chain_id: String,
    pub execution_id: String,
    pub decision_id: String,
    pub proofs: Vec<String>,
    pub claims: Vec<String>,
    pub is_valid_chain: bool,
}

pub struct ICPDAGValidator {
    claims: HashMap<String, Claim>,
    proofs: HashMap<String, Proof>,
    decisions: HashMap<String, Decision>,
    executions: HashMap<String, Execution>,
    messages: Vec<AgentMessage>,
    violations: Vec<ProtocolViolation>,
}

impl ICPDAGValidator {
    pub fn new() -> Self {
        ICPDAGValidator {
            claims: HashMap::new(),
            proofs: HashMap::new(),
            decisions: HashMap::new(),
            executions: HashMap::new(),
            messages: Vec::new(),
            violations: Vec::new(),
        }
    }

    /// Register a claim in the validation system
    pub fn register_claim(&mut self, claim: Claim) {
        self.claims.insert(claim.id.clone(), claim);
    }

    /// Register a proof linking claims
    pub fn register_proof(&mut self, proof: Proof) {
        self.proofs.insert(proof.claim_id.clone(), proof);
    }

    /// Register a decision with supporting/conflicting proofs
    pub fn register_decision(&mut self, decision: Decision) {
        self.decisions.insert(decision.decision_id.clone(), decision);
    }

    /// Register an execution of a decision
    pub fn register_execution(&mut self, execution: Execution) {
        self.executions.insert(execution.exec_id.clone(), execution);
    }

    /// Register agent-to-agent communication messages
    pub fn register_message(&mut self, message: AgentMessage) {
        self.messages.push(message);
    }

    /// Rule I3: Unknown claims cannot authorize
    fn validate_i3_unknown_claims(&mut self) {
        for (decision_id, decision) in &self.decisions {
            for proof_id in &decision.supporting_proofs {
                if let Some(proof) = self.proofs.get(proof_id) {
                    for claim_id in &proof.proof_chain {
                        if let Some(claim) = self.claims.get(claim_id) {
                            if claim.state == ClaimState::Unknown {
                                self.violations.push(ProtocolViolation {
                                    violation_type: "I3_VIOLATION".to_string(),
                                    description: format!(
                                        "Unknown claim {} used in proof chain for decision {}",
                                        claim_id, decision_id
                                    ),
                                    affected_entity: claim_id.clone(),
                                    rule_id: "I3".to_string(),
                                });
                            }
                        }
                    }
                }
            }
        }
    }

    /// Rule I4: Contradicted claims cannot authorize
    fn validate_i4_contradicted_claims(&mut self) {
        for (decision_id, decision) in &self.decisions {
            // Check if supporting proofs depend on contradicted claims
            for proof_id in &decision.supporting_proofs {
                if let Some(proof) = self.proofs.get(proof_id) {
                    for claim_id in &proof.proof_chain {
                        if let Some(claim) = self.claims.get(claim_id) {
                            if claim.state == ClaimState::Contradicted {
                                self.violations.push(ProtocolViolation {
                                    violation_type: "I4_VIOLATION".to_string(),
                                    description: format!(
                                        "Contradicted claim {} used in proof for decision {}",
                                        claim_id, decision_id
                                    ),
                                    affected_entity: claim_id.clone(),
                                    rule_id: "I4".to_string(),
                                });
                            }
                        }
                    }
                }
            }

            // Check for conflicting proofs
            if !decision.conflicting_proofs.is_empty() && !decision.supporting_proofs.is_empty() {
                self.violations.push(ProtocolViolation {
                    violation_type: "I4_VIOLATION".to_string(),
                    description: format!(
                        "Decision {} has both supporting and conflicting proofs",
                        decision_id
                    ),
                    affected_entity: decision_id.clone(),
                    rule_id: "I4".to_string(),
                });
            }
        }
    }

    /// Rule I5: Execution needs authorized decision
    fn validate_i5_execution_chain(&mut self) {
        for (exec_id, execution) in &self.executions {
            if !execution.executed {
                return; // Skip unexecuted
            }

            // Trace: execution → decision → proof → claim
            if let Some(decision) = self.decisions.get(&execution.decision_id) {
                if !decision.authorized {
                    self.violations.push(ProtocolViolation {
                        violation_type: "I5_VIOLATION".to_string(),
                        description: format!(
                            "Execution {} uses unauthorized decision {}",
                            exec_id, &execution.decision_id
                        ),
                        affected_entity: exec_id.clone(),
                        rule_id: "I5".to_string(),
                    });
                    continue;
                }

                // Verify proofs exist and are valid
                for proof_id in &decision.supporting_proofs {
                    if let Some(proof) = self.proofs.get(proof_id) {
                        if !proof.is_valid {
                            self.violations.push(ProtocolViolation {
                                violation_type: "I5_VIOLATION".to_string(),
                                description: format!(
                                    "Execution {} depends on invalid proof {}",
                                    exec_id, proof_id
                                ),
                                affected_entity: exec_id.clone(),
                                rule_id: "I5".to_string(),
                            });
                        }
                    }
                }
            }
        }
    }

    /// Rule I9: Claim state consistency
    fn validate_i9_claim_consistency(&mut self) -> ClaimAnalysis {
        let mut analysis = ClaimAnalysis {
            total_claims: self.claims.len(),
            unknown_claims: 0,
            verified_claims: 0,
            contradicted_claims: 0,
            state_inconsistencies: Vec::new(),
        };

        let mut claim_state_map: HashMap<String, HashSet<ClaimState>> = HashMap::new();

        for (claim_id, claim) in &self.claims {
            match claim.state {
                ClaimState::Unknown => analysis.unknown_claims += 1,
                ClaimState::Verified => analysis.verified_claims += 1,
                ClaimState::Contradicted => analysis.contradicted_claims += 1,
                ClaimState::Pending => {}
            }

            claim_state_map
                .entry(claim_id.clone())
                .or_insert_with(HashSet::new)
                .insert(claim.state.clone());
        }

        // Check for simultaneous unknown+verified
        for (claim_id, states) in &claim_state_map {
            if states.contains(&ClaimState::Unknown) && states.contains(&ClaimState::Verified) {
                analysis.state_inconsistencies.push(claim_id.clone());
                self.violations.push(ProtocolViolation {
                    violation_type: "I9_VIOLATION".to_string(),
                    description: format!(
                        "Claim {} has simultaneous unknown and verified states",
                        claim_id
                    ),
                    affected_entity: claim_id.clone(),
                    rule_id: "I9".to_string(),
                });
            }

            // Cannot be both verified and contradicted
            if states.contains(&ClaimState::Verified) && states.contains(&ClaimState::Contradicted)
            {
                analysis.state_inconsistencies.push(claim_id.clone());
                self.violations.push(ProtocolViolation {
                    violation_type: "I9_VIOLATION".to_string(),
                    description: format!(
                        "Claim {} has simultaneous verified and contradicted states",
                        claim_id
                    ),
                    affected_entity: claim_id.clone(),
                    rule_id: "I9".to_string(),
                });
            }
        }

        analysis
    }

    /// Rules I2 & I10: Acyclicity detection using DFS
    fn validate_acyclicity(&self) -> DAGStructure {
        let mut dag_structure = DAGStructure {
            nodes: Vec::new(),
            edges: Vec::new(),
            is_acyclic: true,
            cycles: Vec::new(),
            topological_sort: Vec::new(),
        };

        // Build dependency graph from messages
        let mut graph: HashMap<String, Vec<String>> = HashMap::new();
        let mut all_agents: HashSet<String> = HashSet::new();

        for message in &self.messages {
            all_agents.insert(message.sender.clone());
            all_agents.insert(message.receiver.clone());

            graph
                .entry(message.sender.clone())
                .or_insert_with(Vec::new)
                .push(message.receiver.clone());

            // Add dependencies
            for dep_id in &message.depends_on {
                if let Some(dep_msg) = self.messages.iter().find(|m| &m.message_id == dep_id) {
                    graph
                        .entry(dep_msg.sender.clone())
                        .or_insert_with(Vec::new)
                        .push(message.sender.clone());
                }
            }
        }

        dag_structure.nodes = all_agents.iter().cloned().collect();

        for (from, tos) in &graph {
            for to in tos {
                dag_structure.edges.push((from.clone(), to.clone()));
            }
        }

        // Detect cycles using DFS
        let cycles = self.detect_cycles(&graph);
        dag_structure.is_acyclic = cycles.is_empty();
        dag_structure.cycles = cycles;

        // Topological sort if acyclic
        if dag_structure.is_acyclic {
            dag_structure.topological_sort = self.topological_sort(&graph);
        }

        dag_structure
    }

    /// Detect cycles using depth-first search
    fn detect_cycles(&self, graph: &HashMap<String, Vec<String>>) -> Vec<Vec<String>> {
        let mut visited: HashMap<String, i32> = HashMap::new();
        let mut cycles: Vec<Vec<String>> = Vec::new();
        let mut path: Vec<String> = Vec::new();

        for node in graph.keys() {
            if !visited.contains_key(node) {
                self.dfs_cycle(node, graph, &mut visited, &mut path, &mut cycles);
            }
        }

        cycles
    }

    /// DFS helper for cycle detection
    fn dfs_cycle(
        &self,
        node: &str,
        graph: &HashMap<String, Vec<String>>,
        visited: &mut HashMap<String, i32>,
        path: &mut Vec<String>,
        cycles: &mut Vec<Vec<String>>,
    ) {
        visited.insert(node.to_string(), 0); // 0 = visiting
        path.push(node.to_string());

        if let Some(neighbors) = graph.get(node) {
            for neighbor in neighbors {
                match visited.get(neighbor).copied() {
                    None => {
                        self.dfs_cycle(neighbor, graph, visited, path, cycles);
                    }
                    Some(0) => {
                        // Back edge found - cycle detected
                        if let Some(cycle_start) = path.iter().position(|n| n == neighbor) {
                            let cycle = path[cycle_start..].to_vec();
                            cycles.push(cycle);
                        }
                    }
                    _ => {} // Already visited
                }
            }
        }

        path.pop();
        visited.insert(node.to_string(), 1); // 1 = done
    }

    /// Topological sort using Kahn's algorithm
    fn topological_sort(&self, graph: &HashMap<String, Vec<String>>) -> Vec<String> {
        let mut in_degree: HashMap<String, usize> = HashMap::new();
        let mut all_nodes: HashSet<String> = HashSet::new();

        // Initialize in-degrees
        for (from, tos) in graph {
            all_nodes.insert(from.clone());
            in_degree.entry(from.clone()).or_insert(0);

            for to in tos {
                all_nodes.insert(to.clone());
                *in_degree.entry(to.clone()).or_insert(0) += 1;
            }
        }

        let mut queue: VecDeque<String> = VecDeque::new();

        for node in &all_nodes {
            if in_degree.get(node).copied().unwrap_or(0) == 0 {
                queue.push_back(node.clone());
            }
        }

        let mut result: Vec<String> = Vec::new();

        while let Some(node) = queue.pop_front() {
            result.push(node.clone());

            if let Some(neighbors) = graph.get(&node) {
                for neighbor in neighbors {
                    let degree = in_degree.entry(neighbor.clone()).or_insert(0);
                    *degree -= 1;

                    if *degree == 0 {
                        queue.push_back(neighbor.clone());
                    }
                }
            }
        }

        result
    }

    /// Build execution chains: execution → decision → proofs → claims
    fn build_execution_chains(&self) -> Vec<ExecutionChain> {
        let mut chains: Vec<ExecutionChain> = Vec::new();

        for (exec_id, execution) in &self.executions {
            let mut chain = ExecutionChain {
                chain_id: format!("chain_{}", exec_id),
                execution_id: exec_id.clone(),
                decision_id: execution.decision_id.clone(),
                proofs: Vec::new(),
                claims: Vec::new(),
                is_valid_chain: true,
            };

            if let Some(decision) = self.decisions.get(&execution.decision_id) {
                chain.proofs = decision.supporting_proofs.clone();

                for proof_id in &chain.proofs {
                    if let Some(proof) = self.proofs.get(proof_id) {
                        for claim_id in &proof.proof_chain {
                            chain.claims.push(claim_id.clone());
                        }
                    }
                }

                // Validate chain
                chain.is_valid_chain = decision.authorized
                    && chain.proofs.iter().all(|p| {
                        self.proofs
                            .get(p)
                            .map(|proof| proof.is_valid)
                            .unwrap_or(false)
                    })
                    && chain.claims.iter().all(|c| {
                        self.claims
                            .get(c)
                            .map(|claim| claim.state == ClaimState::Verified)
                            .unwrap_or(false)
                    });
            }

            chains.push(chain);
        }

        chains
    }

    /// Perform complete validation
    pub fn validate(&mut self) -> ValidationReport {
        self.violations.clear();

        // Rule validations
        self.validate_i3_unknown_claims();
        self.validate_i4_contradicted_claims();
        self.validate_i5_execution_chain();

        let claim_analysis = self.validate_i9_claim_consistency();
        let dag_structure = self.validate_acyclicity();

        // Check acyclicity rules
        if !dag_structure.is_acyclic {
            for cycle in &dag_structure.cycles {
                self.violations.push(ProtocolViolation {
                    violation_type: "I2_I10_VIOLATION".to_string(),
                    description: format!("Cycle detected in DAG: {:?}", cycle),
                    affected_entity: cycle.join(" -> "),
                    rule_id: "I2_I10".to_string(),
                });
            }
        }

        let execution_chains = self.build_execution_chains();

        let is_valid = self.violations.is_empty();

        ValidationReport {
            violations: self.violations.clone(),
            is_valid,
            dag_structure,
            claim_analysis,
            execution_chains,
        }
    }
}

impl fmt::Display for ValidationReport {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        writeln!(f, "=== ICP-DAG Governance Protocol Validation Report ===")?;
        writeln!(f)?;

        writeln!(f, "Overall Status: {}", if self.is_valid { "VALID" } else { "INVALID" })?;
        writeln!(f, "Total Violations: {}", self.violations.len())?;
        writeln!(f)?;

        if !self.violations.is_empty() {
            writeln!(f, "--- Protocol Violations ---")?;
            for (idx, violation) in self.violations.iter().enumerate() {
                writeln!(f, "{}. [{}] {}", idx + 1, violation.rule_id, violation.violation_type)?;
                writeln!(f, "   Entity: {}", violation.affected_entity)?;
                writeln!(f, "   Desc: {}", violation.description)?;
            }
            writeln!(f)?;
        }

        writeln!(f, "--- Claim Analysis ---")?;
        writeln!(f, "Total Claims: {}", self.claim_analysis.total_claims)?;
        writeln!(f, "Verified: {}", self.claim_analysis.verified_claims)?;
        writeln!(f, "Unknown: {}", self.claim_analysis.unknown_claims)?;
        writeln!(f, "Contradicted: {}", self.claim_analysis.contradicted_claims)?;
        writeln!(f, "State Inconsistencies: {}", self.claim_analysis.state_inconsistencies.len())?;
        writeln!(f)?;

        writeln!(f, "--- DAG Structure ---")?;
        writeln!(f, "Nodes: {}", self.dag_structure.nodes.len())?;
        writeln!(f, "Edges: {}", self.dag_structure.edges.len())?;
        writeln!(f, "Acyclic: {}", self.dag_structure.is_acyclic)?;
        if !self.dag_structure.cycles.is_empty() {
            writeln!(f, "Cycles Found: {}", self.dag_structure.cycles.len())?;
        }
        writeln!(f)?;

        writeln!(f, "--- Execution Chains ---")?;
        writeln!(f, "Total Chains: {}", self.execution_chains.len())?;
        for chain in &self.execution_chains {
            writeln!(f, "  {}: {} proofs, {} claims, Valid: {}",
                chain.chain_id, chain.proofs.len(), chain.claims.len(), chain.is_valid_chain)?;
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_i3_unknown_claims() {
        let mut validator = ICPDAGValidator::new();

        let unknown_claim = Claim {
            id: "claim_1".to_string(),
            agent: "agent_a".to_string(),
            content: "test".to_string(),
            state: ClaimState::Unknown,
            timestamp: 0,
        };
        validator.register_claim(unknown_claim);

        let proof = Proof {
            claim_id: "proof_1".to_string(),
            proof_chain: vec!["claim_1".to_string()],
            verifier_agent: "agent_b".to_string(),
            is_valid: true,
        };
        validator.register_proof(proof);

        let decision = Decision {
            decision_id: "dec_1".to_string(),
            agent: "agent_c".to_string(),
            supporting_proofs: vec!["proof_1".to_string()],
            conflicting_proofs: vec![],
            authorized: true,
            timestamp: 0,
        };
        validator.register_decision(decision);

        let report = validator.validate();
        assert!(!report.is_valid);
        assert!(report.violations.iter().any(|v| v.rule_id == "I3"));
    }

    #[test]
    fn test_i9_state_consistency() {
        let mut validator = ICPDAGValidator::new();

        let claim = Claim {
            id: "claim_1".to_string(),
            agent: "agent_a".to_string(),
            content: "test".to_string(),
            state: ClaimState::Verified,
            timestamp: 0,
        };
        validator.register_claim(claim);

        let report = validator.validate();
        assert!(report.is_valid);
        assert_eq!(report.claim_analysis.verified_claims, 1);
    }
}

fn main() {
    let mut validator = ICPDAGValidator::new();

    // Example: Register verified claim
    let verified_claim = Claim {
        id: "claim_verified_1".to_string(),
        agent: "agent_governance".to_string(),
        content: "Governance protocol v1.0 active".to_string(),
        state: ClaimState::Verified,
        timestamp: 1000,
    };
    validator.register_claim(verified_claim);

    // Example: Register proof
    let proof = Proof {
        claim_id: "proof_1".to_string(),
        proof_chain: vec!["claim_verified_1".to_string()],
        verifier_agent: "agent_validator".to_string(),
        is_valid: true,
    };
    validator.register_proof(proof);

    // Example: Register authorized decision
    let decision = Decision {
        decision_id: "decision_1".to_string(),
        agent: "agent_consensus".to_string(),
        supporting_proofs: vec!["proof_1".to_string()],
        conflicting_proofs: vec![],
        authorized: true,
        timestamp: 1001,
    };
    validator.register_decision(decision);

    // Example: Register execution
    let execution = Execution {
        exec_id: "exec_1".to_string(),
        agent: "agent_executor".to_string(),
        decision_id: "decision_1".to_string(),
        executed: true,
        timestamp: 1002,
    };
    validator.register_execution(execution);

    // Validate
    let report = validator.validate();
    println!("{}", report);
    println!("\nDAG as JSON:");
    println!("{}", serde_json::to_string_pretty(&report.dag_structure).unwrap());
}
