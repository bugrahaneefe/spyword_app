import SwiftUI

enum NavigationType {
    case push
    case modal
    case sheet
}

class Router: ObservableObject {
    @Published var pushView: AnyView? = nil
    @Published var sheetView: AnyView? = nil
    @Published var modalView: AnyView? = nil

    func navigate<Destination: View>(to view: Destination, type: NavigationType) {
        switch type {
        case .push:
            pushView = AnyView(view)
        case .sheet:
            sheetView = AnyView(view)
        case .modal:
            modalView = AnyView(view)
        }
    }

    func dismissSheet() {
        sheetView = nil
    }

    func dismissModal() {
        modalView = nil
    }

    func pop() {
        pushView = nil
    }
}

struct WithRouter: ViewModifier {
    @StateObject private var router = Router()

    func body(content: Content) -> some View {
        NavigationStack {
            ZStack {
                content
                    .environmentObject(router)
                    .navigationDestination(isPresented: Binding(
                        get: { router.pushView != nil },
                        set: { if !$0 { router.pop() } })
                    ) {
                        router.pushView
                    }
                    .sheet(isPresented: Binding(
                        get: { router.sheetView != nil },
                        set: { if !$0 { router.dismissSheet() } })
                    ) {
                        router.sheetView
                    }
                    .fullScreenCover(isPresented: Binding(
                        get: { router.modalView != nil },
                        set: { if !$0 { router.dismissModal() } })
                    ) {
                        router.modalView
                    }
            }
        }
    }
}
