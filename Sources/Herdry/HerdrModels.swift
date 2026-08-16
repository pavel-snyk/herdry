struct SessionList: Decodable, Sendable {
    let sessions: [HerdrSession]
}

struct HerdrSession: Decodable, Identifiable, Sendable {
    let name: String
    let running: Bool
    let `default`: Bool

    var id: String { name }
}

struct SessionSnapshot: Identifiable, Sendable {
    let session: HerdrSession
    let blockedCount: Int?

    var id: String { session.id }
}

struct AgentListResponse: Decodable, Sendable {
    let result: AgentListResult
}

struct AgentListResult: Decodable, Sendable {
    let agents: [HerdrAgent]
}

struct HerdrAgent: Decodable, Sendable {
    let agentStatus: String

    enum CodingKeys: String, CodingKey {
        case agentStatus = "agent_status"
    }
}
