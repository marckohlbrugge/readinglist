import SwiftUI

struct DemoContentWrapper: View {
    @State private var smartFolderStore: SmartFolderStore
    @State private var viewModel: ReadingListViewModel

    init() {
        let store = SmartFolderStore()
        _smartFolderStore = State(initialValue: store)
        _viewModel = State(
            initialValue: ReadingListViewModel(
                smartFolderStore: store,
                demoItems: DemoReadingListData.makeItems()
            )
        )
    }

    var body: some View {
        ContentView(viewModel: viewModel, smartFolderStore: smartFolderStore)
            .task {
                viewModel.reload()
            }
    }
}
