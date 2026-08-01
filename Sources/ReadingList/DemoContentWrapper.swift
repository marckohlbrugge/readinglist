import SwiftUI

struct DemoContentWrapper: View {
    let smartFolderStore: SmartFolderStore

    @State private var viewModel: ReadingListViewModel

    init(smartFolderStore: SmartFolderStore) {
        self.smartFolderStore = smartFolderStore
        _viewModel = State(
            initialValue: ReadingListViewModel(
                smartFolderStore: smartFolderStore,
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
