import SwiftUI
import Firebase

struct GameSettings {
    enum WordMode { case random, custom }
    enum WordCategory: String, CaseIterable {
        case world          // dünyaca bilinen kişi/karakter
        case turkiye        // Türkiye’de bilinen kişi/karakter
        case worldFootball  // dünya futbolu
        case nfl            // NFL
    }

    var mode: WordMode
    var customWord: String?          // mode == .custom ise zorunlu
    var spyCount: Int
    var totalRounds: Int
    var category: WordCategory       // NEW
}

final class RoomViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var hostId: String?
    @Published var status: String = "waiting"
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var chosen: Set<String> = []
    @Published var mode: GameSettings.WordMode = .random
    @Published var customWord: String = ""
    @Published var spyCount: Int = 1
    @Published var totalRounds: Int = 3
    @Published var category: GameSettings.WordCategory = .world
    private let roomCode: String
    private var roomListener: ListenerRegistration?
    private var playersListener: ListenerRegistration?

    private var roomRef: DocumentReference {
        Firestore.firestore().collection("rooms").document(roomCode)
    }

    init(roomCode: String) {
        self.roomCode = roomCode
        startListeners()
    }

    deinit {
        roomListener?.remove()
        playersListener?.remove()
    }

    // MARK: - Realtime listeners (aynı + status okuma)
    private func startListeners() {
        roomListener = roomRef.addSnapshotListener { snap, error in
            if let data = snap?.data(),
               let info = data["info"] as? [String:Any] {
                DispatchQueue.main.async {
                    self.hostId = info["hostId"] as? String
                    self.status  = (info["status"] as? String) ?? "waiting"
                    self.isLoading = false
                }
            } else if let err = error {
                DispatchQueue.main.async {
                    self.errorMessage = err.localizedDescription
                    self.isLoading = false
                }
            }
        }

        playersListener = roomRef.collection("players")
            .addSnapshotListener { snap, error in
                if let docs = snap?.documents {
                    let loaded = docs.map { doc -> Player in
                        let d = doc.data()
                        return Player(
                            id: doc.documentID,
                            name: d["name"] as? String ?? "Anonim",
                            role: d["role"] as? String,
                            isEliminated: d["isEliminated"] as? Bool,
                            isSelected: d["isSelected"] as? Bool
                        )
                    }
                    DispatchQueue.main.async { self.players = loaded }
                } else if let err = error {
                    DispatchQueue.main.async { self.errorMessage = err.localizedDescription }
                }
            }
    }

    // MARK: - Status helpers
    func setStatus(_ value: String) {
        roomRef.setData(["info": ["status": value]], merge: true)
    }

    func beginArranging() {
        setStatus("arranging")
    }

    // MARK: - Selection persist (status değişmez!)
    func saveSelection(_ selectedIds: [String], completion: ((Error?) -> Void)? = nil) {
        let batch = Firestore.firestore().batch()
        let setSelected: Set<String> = Set(selectedIds)

        // İsteğe bağlı: info.lockedPlayers alanı
        batch.setData(["info": ["lockedPlayers": Array(setSelected)]], forDocument: roomRef, merge: true)

        for p in players {
            let doc = roomRef.collection("players").document(p.id)
            batch.updateData(["isSelected": setSelected.contains(p.id)], forDocument: doc)
        }

        batch.commit { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Start game with settings
    func startGame(selectedIds: [String], settings: GameSettings) {
            // Kelime
            let word: String = {
                switch settings.mode {
                case .random:
                    return WordPools.randomWord(from: settings.category)
                case .custom:
                    return settings.customWord?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? settings.customWord!.trimmingCharacters(in: .whitespacesAndNewlines)
                    : "Kelime"
                }
            }()

            // Roller
            var eligibleForSpy = selectedIds
            if settings.mode == .custom, let host = hostId {
                // host kelimeyi girdiyse spy olamaz
                eligibleForSpy.removeAll { $0 == host }
            }

            let spyCount = max(0, min(settings.spyCount, max(0, eligibleForSpy.count)))
            let spies = Array(eligibleForSpy.shuffled().prefix(spyCount))
            let spySet = Set(spies)

            let batch = Firestore.firestore().batch()

            // Oyuncular
            for p in players {
                let doc = roomRef.collection("players").document(p.id)
                let isInGame = selectedIds.contains(p.id)
                var updates: [String:Any] = ["isSelected": isInGame]
                if isInGame {
                    let role = spySet.contains(p.id) ? "spy" : "knower"
                    updates["role"] = role
                    updates["isEliminated"] = false
                } else {
                    updates["role"] = FieldValue.delete()
                }
                batch.updateData(updates, forDocument: doc)
            }

            // sıra
            let turnOrder = selectedIds.shuffled()

            var info: [String:Any] = [
                "status": "the game",
                "word": word,
                "spyCount": spyCount,
                "totalRounds": settings.totalRounds,
                "lockedPlayers": selectedIds,
                "turnOrder": turnOrder,
                "category": settings.category.rawValue   // NEW (isterseniz UI’da gösterebilirsiniz)
            ]

            batch.setData(["info": info], forDocument: roomRef, merge: true)

            batch.commit { [weak self] error in
                if let err = error {
                    DispatchQueue.main.async { self?.errorMessage = err.localizedDescription }
                }
            }
        }

    // Var olan remove() fonksiyonun aynı
    func remove(player: Player) {
        roomRef.collection("players").document(player.id).delete { [weak self] error in
            if let err = error { self?.errorMessage = err.localizedDescription }
        }
    }
}

enum WordPools {
    static func randomWord(from category: GameSettings.WordCategory) -> String {
        let pool: [String]
        switch category {
        case .world:         pool = world
        case .turkiye:       pool = turkiye
        case .worldFootball: pool = worldFootball
        case .nfl:           pool = nfl
        }
        return pool.randomElement() ?? "Kelime"
    }

    // 1) WORLD – 50 (global kişi/karakter)
    static let world: [String] = [
        "Lionel Messi","Cristiano Ronaldo","Beyoncé","Taylor Swift","Michael Jordan",
        "LeBron James","Kobe Bryant","Oprah Winfrey","Elon Musk","Bill Gates",
        "Steve Jobs","Albert Einstein","Isaac Newton","Nikola Tesla","William Shakespeare",
        "Sherlock Holmes","Harry Potter","Hermione Granger","Ron Weasley","Darth Vader",
        "Luke Skywalker","Yoda","Batman","Superman","Wonder Woman",
        "Spider-Man","Iron Man","Captain America","Hulk","Thor",
        "Black Widow","James Bond","Lara Croft","Mario","Sonic",
        "Pikachu","Link","Zelda","Kratos","Master Chief",
        "Geralt of Rivia","Gandalf","Frodo Baggins","Aragorn","Legolas",
        "Gollum","Shrek","Donkey","SpongeBob SquarePants","Patrick Star"
    ]

    // 2) TÜRKİYE – 50 (Türkiye’de çok bilinen kişi/karakter)
    static let turkiye: [String] = [
        "Kemal Sunal","Şener Şen","Cem Yılmaz","Barış Manço","Tarkan",
        "Sezen Aksu","Ajda Pekkan","İbrahim Tatlıses","Kıvanç Tatlıtuğ","Beren Saat",
        "Haluk Bilginer","Engin Akyürek","Kenan İmirzalioğlu","Halit Ergenç","Bergüzar Korel",
        "Meryem Uzerli","Ata Demirer","Demet Akbağ","Gülse Birsel","Okan Bayülgen",
        "Acun Ilıcalı","Nusret","Zeki Müren","Orhan Gencebay","Müslüm Gürses",
        "Cem Karaca","Teoman","Mazhar Fuat Özkan","Barış Akarsu","Aleyna Tilki",
        "Hadise","Edis","Murat Boz","Yılmaz Erdoğan","Ezgi Mola",
        "Aras Bulut İynemli","Çağatay Ulusoy","Hande Erçel","Burak Özçivit","Serenay Sarıkaya",
        "Kenan Doğulu","Sertab Erener","Nil Karaibrahimgil","Gökhan Özoğuz","Athena",
        "Ezhel","Ceza","Sagopa Kajmer","Kıraç","Mabel Matiz"
    ]

    // 3) WORLD FOOTBALL – 50
    static let worldFootball: [String] = [
        "Lionel Messi","Cristiano Ronaldo","Neymar","Kylian Mbappé","Erling Haaland",
        "Robert Lewandowski","Karim Benzema","Luka Modrić","Andrés Iniesta","Xavi",
        "Zinedine Zidane","Ronaldinho","Kaká","Mohamed Salah","Sadio Mané",
        "Kevin De Bruyne","Harry Kane","Wayne Rooney","David Beckham","Thierry Henry",
        "Didier Drogba","Samuel Eto'o","Zlatan Ibrahimović","Andrea Pirlo","Paolo Maldini",
        "Sergio Ramos","Gerard Piqué","Virgil van Dijk","Marcelo","Dani Alves",
        "Iker Casillas","Gianluigi Buffon","Manuel Neuer","Petr Čech","Frank Lampard",
        "Steven Gerrard","Paul Scholes","Ryan Giggs","George Best","Bobby Charlton",
        "Johan Cruyff","Marco van Basten","Pelé","Diego Maradona","Romário",
        "Rivaldo","Roberto Carlos","Philipp Lahm","Francesco Totti","Andrea Barzagli"
    ]

    // 4) NFL – 50
    static let nfl: [String] = [
        "Tom Brady","Patrick Mahomes","Peyton Manning","Joe Montana","Aaron Rodgers",
        "Drew Brees","Brett Favre","Dan Marino","John Elway","Steve Young",
        "Jim Kelly","Terry Bradshaw","Ben Roethlisberger","Eli Manning","Troy Aikman",
        "Russell Wilson","Josh Allen","Joe Burrow","Justin Herbert","Barry Sanders",
        "Walter Payton","Emmitt Smith","Adrian Peterson","LaDainian Tomlinson","Jerry Rice",
        "Randy Moss","Terrell Owens","Larry Fitzgerald","Calvin Johnson","Rob Gronkowski",
        "Tony Gonzalez","Travis Kelce","Antonio Gates","Deion Sanders","Ray Lewis",
        "Lawrence Taylor","J.J. Watt","Aaron Donald","Reggie White","Bruce Smith",
        "Ed Reed","Troy Polamalu","Charles Woodson","Darrelle Revis","Richard Sherman",
        "Marshawn Lynch","Derrick Henry","Cooper Kupp","Odell Beckham Jr.","Saquon Barkley"
    ]
}

