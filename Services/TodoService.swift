import Foundation
import Supabase

final class TodoService {
    static let shared = TodoService()
    private let db = SupabaseService.shared.client
    private let table = "todo_items"

    // ── Fetch ────────────────────────────────────────────────

    /// Fetch all items for the current user (used on launch / full sync)
    func fetchAll(userId: UUID) async throws -> [TodoItem] {
        let items: [TodoItem] = try await db
            .from(table)
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
        return items
    }

    /// Fetch items for a specific date range
    func fetch(userId: UUID, from startDate: String, to endDate: String) async throws -> [TodoItem] {
        var allItems: [TodoItem] = []
        var offset = 0
        let batchSize = 1000
        
        while true {
            let batch: [TodoItem] = try await db
                .from(table)
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("list_date", value: startDate)
                .lte("list_date", value: endDate)
                .order("created_at", ascending: true)
                .range(from: offset, to: offset + batchSize - 1)
                .execute()
                .value
            
            allItems.append(contentsOf: batch)
            
            if batch.count < batchSize {
                // Last batch — we've fetched everything
                break
            }
            
            offset += batchSize
        }
        
        return allItems
    }
    
    func fetchTemplates(userId: UUID) async throws -> [TodoItem] {
        let items: [TodoItem] = try await db
            .from(table)
            .select()
            .eq("user_id", value: userId.uuidString)
            .neq("recurrence", value: "once")
            .is("template_id", value: nil)
            .execute()
            .value
        return items
    }

    // ── Insert ───────────────────────────────────────────────

    func insert(_ item: TodoItem) async throws -> TodoItem {
        let result: [TodoItem] = try await db
            .from(table)
            .insert(item)
            .select()
            .execute()
            .value
        guard let inserted = result.first else {
            throw TodoServiceError.noDataReturned
        }
        return inserted
    }

    // ── Update ───────────────────────────────────────────────

    func update(_ item: TodoItem) async throws -> TodoItem {
        var updated = item
        updated.updatedAt = Date()

        let result: [TodoItem] = try await db
            .from(table)
            .update(updated)
            .eq("id", value: item.id.uuidString)
            .select()
            .execute()
            .value
        guard let returned = result.first else {
            throw TodoServiceError.noDataReturned
        }
        return returned
    }

    // ── Delete ───────────────────────────────────────────────

    func delete(id: UUID) async throws {
        try await db
            .from(table)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    func deleteSeries(templateId: UUID) async throws {
        // Delete spawned copies first
        try await db
            .from(table)
            .delete()
            .eq("template_id", value: templateId.uuidString)
            .execute()
        
        // Then delete the template itself
        try await db
            .from(table)
            .delete()
            .eq("id", value: templateId.uuidString)
            .execute()
    }
    
    // -- Indicies ---------------------------------------------
    private struct OrderUpdate: Encodable {
        let orderIndex: Int
        let updatedAt: Date
        
        enum CodingKeys: String, CodingKey {
            case orderIndex = "order_index"
            case updatedAt  = "updated_at"
        }
    }

    func updateOrderIndices(_ items: [(id: UUID, orderIndex: Int)]) async throws {
        for item in items {
            let update = OrderUpdate(orderIndex: item.orderIndex, updatedAt: Date())
            try await db
                .from(table)
                .update(update)
                .eq("id", value: item.id.uuidString)
                .execute()
        }
    }

    func updateOrderIndicesForSeries(templateId: UUID, orderIndex: Int) async throws {
        let update = OrderUpdate(orderIndex: orderIndex, updatedAt: Date())
        
        try await db
            .from(table)
            .update(update)
            .eq("template_id", value: templateId.uuidString)
            .execute()
        
        try await db
            .from(table)
            .update(update)
            .eq("id", value: templateId.uuidString)
            .execute()
    }

    // ── Real-time ────────────────────────────────────────────

    /// Subscribe to real-time changes for this user's items.
    /// Returns a RealtimeChannel — retain it to keep the subscription alive.
    func subscribeToChanges(
        userId: UUID,
        onInsert: @escaping (TodoItem) -> Void,
        onUpdate: @escaping (TodoItem) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) -> RealtimeChannelV2 {
        let channel = db.realtimeV2.channel("todos-\(userId.uuidString)")

        Task {
            await channel.onPostgresChange(
                InsertAction.self,
                table: table
            ) { action in
                if let item = try? action.decodeRecord(as: TodoItem.self, decoder: .init()) {
                    onInsert(item)
                }
            }

            await channel.onPostgresChange(
                UpdateAction.self,
                table: table
            ) { action in
                if let item = try? action.decodeRecord(as: TodoItem.self, decoder: .init()) {
                    onUpdate(item)
                }
            }

            await channel.onPostgresChange(
                DeleteAction.self,
                table: table
            ) { action in
                if let idString = action.oldRecord["id"]?.value as? String,
                   let uuid = UUID(uuidString: idString) {
                    onDelete(uuid)
                }
            }

            await channel.subscribe()
        }

        return channel
    }
}

// ── Errors ───────────────────────────────────────────────────

enum TodoServiceError: LocalizedError {
    case noDataReturned

    var errorDescription: String? {
        switch self {
        case .noDataReturned: return "No data was returned from the server."
        }
    }
}
