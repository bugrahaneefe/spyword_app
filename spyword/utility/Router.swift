import SwiftUI

enum NavigationType {
    case push
    case modal
    case sheet
}

final class Router: ObservableObject {
    @Published var pushView: AnyView?
    @Published var sheetView: AnyView?
    @Published var modalView: AnyView?
    @Published var rootView: AnyView?

    func navigate<Destination: View>(to view: Destination, type: NavigationType) {
        let wrapped = AnyView(view.environmentObject(self))
        switch type {
        case .push:
            pushView = wrapped
        case .sheet:
            sheetView = wrapped
        case .modal:
            modalView = wrapped
        }
    }

    func dismissSheet() { sheetView = nil }
    func dismissModal() { modalView = nil }
    func pop() { pushView = nil }

    func replace<Destination: View>(with view: Destination) {
        pushView = nil
        sheetView = nil
        modalView = nil
        rootView = AnyView(view.environmentObject(self))
    }
}

struct RootContainer: View {
    @StateObject private var router = Router()
    @StateObject private var lang = LanguageManager()

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if let root = router.rootView {
                        root
                    } else {
                        SplashScreen()
                    }
                }
                .environmentObject(router)
                .environmentObject(lang)
                .environment(\.locale, lang.locale) // 💡 kritik: runtime dil değişimi

                .navigationDestination(isPresented: Binding(
                    get: { router.pushView != nil },
                    set: { if !$0 { router.pop() } })
                ) { router.pushView }

                .sheet(isPresented: Binding(
                    get: { router.sheetView != nil },
                    set: { if !$0 { router.dismissSheet() } })
                ) { router.sheetView }

                .fullScreenCover(isPresented: Binding(
                    get: { router.modalView != nil },
                    set: { if !$0 { router.dismissModal() } })
                ) { router.modalView }
            }
        }
    }
}

