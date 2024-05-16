# TaskStore
A Store where you can store the tasks that describes in Swift concurrency. It is useful when you want to cancel specific tasks at the appropriate points.

For example, it can be used to fetch the image for `UITableViewCell` using `Task`.  
In this case, we require to cancel the `Task`, however, it's not that simple without other implementation changes.  
The following shows example code how to resolve this problem by storing the tasks also it is a completely additional method.

#### Before
```swift
override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(CustomCell.self, for: indexPath)
    Task {
        guard let response = await network.request(url: url) else { return }
        guard let imageURL = URL(string: response.imageURL) else { return }
        let image = await imageLoader.load(from: imageURL)
        cell.update(image: image)
    }
    return cell
}
```

#### After
```swift
override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(CustomCell.self, for: indexPath)
    // ✨ For identifing tasks
    let cellID = ObjectIdentifier(cell)

    // ✨ Cancel tasks that no longer needs
    taskStore.tasks(where: { $0.cellID == cellID })
        .forEach { $0.cancel() }

    // ✨ Assign to variable
    let imageUpdateTask = Task {
        guard let response = await network.request(url: url) else { return }
        try Task.checkCancellation() // ✨ Check cancellation at the appropriate time.

        guard let imageURL = URL(string: response.imageURL) else { return }
        let image = await imageLoader.load(from: imageURL)
        try Task.checkCancellation() // ✨ Check cancellation at the appropriate time.

        cell.update(image: image)
    }
    // ✨ Store a task 
    taskStore.setTask(imageUpdateTask, forKey: CellImageUpdateKey(cellID: cellID, indexPath: indexPath))
    
    return cell
}
```

You can use it anywhere you want to store a Task, not just in the example above!

## Features

## Contribution
Welcome any form of contribution via [issue](https://github.com/woin2ee/TaskStore/issues) or [pull request](https://github.com/woin2ee/TaskStore/pulls), such as any features you'd like to see added, bug reports, etc. 🙌

## Installation
```swift
dependencies: [
    .package(url: "https://github.com/woin2ee/TaskStore.git", .upToNextMajor(from: "0.1.0"))
]
```
