import Foundation

/// A task store.
@available(iOS 13.0, *)
public class TaskStore<Key: Hashable> {
    
    public typealias CancellableTask = Task<Void, Error>
    
    var taskMap: [Key: CancellableTask] = [:]
    
    private let lock: NSLock = NSLock()
    
    public init() {}
    
    /// Sets a `task` for `key` to the store.
    ///
    /// If the task you set is completed, it automatically removed from the store.
    /// The work that remove completed tasks has the lowest priority.
    ///
    /// - Parameters:
    ///   - task: The task to add to the store.
    ///   - key: The key to associate with task.
    public func setTask(_ task: CancellableTask, forKey key: Key) {
        lock.lock()
        taskMap.updateValue(task, forKey: key)
        lock.unlock()
        
        Task(priority: .background) {
            _ = try? await task.value
            _ = lock.withLock {
                taskMap.removeValue(forKey: key)
            }
        }
    }
    
    /// Returns the task identified by the given key.
    ///
    /// - Parameter key: The key to associate with task.
    /// - Returns: The task identified by the given key. Otherwise, nil if the task for the given key doesn't exist or completed already.
    public func task(forKey key: Key) -> CancellableTask? {
        lock.lock(); defer { lock.unlock() }
        return taskMap[key]
    }
    
    /// Returns the tasks in the store that satisfies the given predicate.
    /// - Parameter predicate: <#predicate description#>
    /// - Returns: <#description#>
    public func tasks(where predicate: (Key) -> Bool) -> [CancellableTask] {
        return taskMap
            .filter { key, _ in predicate(key) }
            .map(\.value)
    }
    
    subscript(key: Key) -> CancellableTask? {
        return task(forKey: key)
    }
}
