// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CompareFilesViewer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CompareFilesViewer", targets: ["CompareFilesViewer"])
    ],
    targets: [
        .executableTarget(
            name: "CompareFilesViewer",
            path: "Sources/CompareFilesViewer"
        )
    ]
)
