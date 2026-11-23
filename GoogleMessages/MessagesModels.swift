import Foundation

struct MessageConversation: Identifiable, Hashable, Decodable {
    var id: String
    var title: String
    var preview: String
    var time: String
    var unread: Bool
    var group: Bool
    var avatarURL: String?
}

struct MessageItem: Identifiable, Hashable, Decodable {
    var id: String
    var text: String
    var time: String
    var outgoing: Bool
    var status: String
    var attachment: String?
}

struct MessagesSnapshot: Decodable {
    var connected: Bool
    var conversations: [MessageConversation]
    var messages: [MessageItem]
    var activeTitle: String
    var status: String
}
