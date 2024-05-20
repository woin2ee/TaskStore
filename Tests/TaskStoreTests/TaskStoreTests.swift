@testable import TaskStore
import XCTest

final class TaskStoreTests: XCTestCase {
    
    func test_concurrentAccess() {
        let taskStore = TaskStore<String>()
        let task = Task {
            sleep(1)
            throw TestError.test
        }
        taskStore.setTask(task, forKey: "TestKey")
        
        (1...100).forEach { _ in
            DispatchQueue.global().async {
                taskStore.setTask(task, forKey: "TestKey")
                _ = taskStore.task(forKey: "TestKey")
            }
        }
        
        (1...100).forEach { _ in
            DispatchQueue.global().async {
                taskStore.setTask(task, forKey: "TestKey")
                _ = taskStore.tasks(where: { $0 == "TestKey" })
            }
        }
    }
    
    func test_subscript() {
        let taskStore = TaskStore<Int>()
        taskStore.setTask(
            Task {
                usleep(100_000) // 100ms
            },
            forKey: 0
        )
        XCTAssertNotNil(taskStore[0])
    }
    
    func test_searchTasksWithPredicate() {
        struct CustomKey: Hashable {
            let number: Int
        }
        
        let taskStore = TaskStore<CustomKey>()
        
        for number in 1...10 {
            let task = Task {
                sleep(1)
                try Task.checkCancellation()
                XCTAssert(true)
            }
            taskStore.setTask(task, forKey: CustomKey(number: number))
        }
        
        XCTAssertEqual(taskStore.tasks(where: { $0.number < 4 }).count, 3)
        
        sleep(2) // Wait enough for all works such as background task that remove above task or work that cancel above task in global dispatch queue.
        
        XCTAssertEqual(taskStore.tasks(where: { _ in true }).count, 0)
    }
    
    func test_multipleTasksProcessing() async throws {
        actor Count {
            var count = 0
            func increase() {
                count += 1
            }
        }
        
        let taskStore = TaskStore<Int>()
        let taskCount = 10
        let successCount = Count()
        let cancelMask = [
            true,
            false, // Index: 1
            true,
            true,
            false, // 4
            false, // 5
            true,
            false, // 7
            true,
            true
        ]
        
        for order in 0..<taskCount {
            let task = Task {
                sleep(1)
                try Task.checkCancellation()
                await successCount.increase()
            }
            taskStore.setTask(task, forKey: order)
        }
        
        let beforeCount = await successCount.count
        XCTAssertEqual(beforeCount, 0)
        XCTAssertEqual(taskStore.taskMap.count, taskCount)
        
        cancelMask.enumerated()
            .filter { $1 }
            .forEach { index, _ in
                taskStore.task(forKey: index)?.cancel()
            }
        
        sleep(3) // Wait enough for all works such as background task that remove above task or work that cancel above task in global dispatch queue.
        
        let afterCount = await successCount.count
        XCTAssertEqual(afterCount, cancelMask.filter({ !$0 }).count) // `false` count
        XCTAssertEqual(taskStore.taskMap.count, 0)
    }
    
    func test_successImageUpdate_withTask() async throws {
        let taskStore = TaskStore<String>()
        let imageView = await UIImageView()
        
        let imageUpdatingTask = Task {
            sleep(1) // Networking...
            let imageName = "star"
            
            // Check cancellation after done networking before do additional processes.
            try Task.checkCancellation()
            
            sleep(1) // Do additional processes...
            let image = UIImage(systemName: imageName)!
            
            // Check cancellation after done additional processes before actually update image.
            try Task.checkCancellation()
            
            DispatchQueue.main.async {
                // Actual update
                imageView.image = image
            }
        }
        
        taskStore.setTask(imageUpdatingTask, forKey: "image-updating") // Set task to `TaskStore`.
        
        let whenToNeedCancel: DispatchTime = .now() + 2.5 // It time to already complete the image update.
        DispatchQueue.global().asyncAfter(deadline: whenToNeedCancel) {
            let task = taskStore.task(forKey: "image-updating")
            task?.cancel()
        }
        
        XCTAssertNotNil(taskStore.task(forKey: "image-updating"))
        
        _ = try await imageUpdatingTask.value // Check if complete the task.
        
        DispatchQueue.main.async {
            XCTAssertEqual(imageView.image?.pngData(), UIImage(systemName: "star")?.pngData())
        }
        
        sleep(3) // Wait enough for all works such as background task that remove above task or work that cancel above task in global dispatch queue.
        
        XCTAssertNil(taskStore.task(forKey: "image-updating"))
    }
    
    func test_failureImageUpdate_withTask() async throws {
        let taskStore = TaskStore<String>()
        let imageView = await UIImageView()
        
        let imageUpdatingTask = Task {
            sleep(1) // Networking...
            let imageName = "star"
            
            // Check cancellation after done networking before do additional processes.
            try Task.checkCancellation()
            
            sleep(1) // Do additional processes...
            let image = UIImage(systemName: imageName)!
            
            // Check cancellation after done additional processes before actually update image.
            try Task.checkCancellation()
            
            DispatchQueue.main.async {
                // Actual update
                imageView.image = image
                XCTFail("This task did not stop, check the point that cancel the task.")
            }
        }
        
        taskStore.setTask(imageUpdatingTask, forKey: "image-updating") // Set task to `TaskStore`.
        
        let whenToNeedCancel: DispatchTime = .now() + 1.5 // Not enough time to complete the image update.
        DispatchQueue.global().asyncAfter(deadline: whenToNeedCancel) {
            let task = taskStore.task(forKey: "image-updating")
            task?.cancel()
        }
        
        XCTAssertNotNil(taskStore.task(forKey: "image-updating"))
        
        _ = try? await imageUpdatingTask.value // Check if complete the task.(Using `try?` so that test don't break.)
        
        DispatchQueue.main.async {
            XCTAssertNil(imageView.image)
        }
        
        sleep(3) // Wait enough for all works such as background task that remove above task or work that cancel above task in global dispatch queue.
        
        XCTAssertNil(taskStore.task(forKey: "image-updating"))
    }
}
