import SwiftUI
import Firebase

struct GameSettings {
    enum WordMode { case random, custom }
    var mode: WordMode
    var customWord: String?          // mode == .custom ise zorunlu
    var spyCount: Int
    var totalRounds: Int
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
                let pool = [
                    // Futbolcular
                    "Lionel Messi", "Cristiano Ronaldo", "Neymar", "Kylian Mbappé", "Ronaldinho",
                    "Diego Maradona", "Pelé", "Zinedine Zidane", "David Beckham", "Didier Drogba",
                    "Mesut Özil", "Arda Turan", "Hakan Şükür", "Burak Yılmaz", "Alex de Souza",

                    // Basketbolcular
                    "Michael Jordan", "LeBron James", "Kobe Bryant", "Shaquille O'Neal", "Stephen Curry",
                    "Giannis Antetokounmpo", "Dirk Nowitzki", "Kevin Durant", "Luka Dončić", "Magic Johnson",

                    // Şarkıcılar
                    "Michael Jackson", "Elvis Presley", "Madonna", "Beyoncé", "Taylor Swift",
                    "Ed Sheeran", "Adele", "Rihanna", "Shakira", "Freddie Mercury",
                    "Barış Manço", "Tarkan", "Sezen Aksu", "Ajda Pekkan", "İbrahim Tatlıses",

                    // Aktörler
                    "Brad Pitt", "Leonardo DiCaprio", "Johnny Depp", "Robert Downey Jr.",
                    "Tom Cruise", "Scarlett Johansson", "Angelina Jolie", "Will Smith", "Morgan Freeman",
                    "Julia Roberts", "Marlon Brando", "Al Pacino", "Robert De Niro", "Natalie Portman",
                    "Kıvanç Tatlıtuğ", "Haluk Bilginer", "Şener Şen", "Kemal Sunal", "Cem Yılmaz",

                    // Siyasetçiler
                    "Mustafa Kemal Atatürk", "Recep Tayyip Erdoğan", "Kemal Kılıçdaroğlu", "Ekrem İmamoğlu",
                    "Barack Obama", "Donald Trump", "Joe Biden", "Vladimir Putin", "Angela Merkel",
                    "Emmanuel Macron", "Winston Churchill", "Nelson Mandela", "Mahatma Gandhi", "Abraham Lincoln",

                    // Tarihî Figürler
                    "Fatih Sultan Mehmet", "Kanuni Sultan Süleyman", "Napolyon Bonapart",
                    "Julius Caesar", "Cleopatra", "Albert Einstein", "Isaac Newton",
                    "Charles Darwin", "Galileo Galilei", "Nikola Tesla",

                    // Oyun Karakterleri
                    "Mario", "Luigi", "Sonic", "Pikachu", "Ash Ketchum",
                    "Lara Croft", "Kratos", "Master Chief", "Geralt of Rivia", "Link",
                    "Zelda", "Donkey Kong", "Pac-Man", "Solid Snake", "Cloud Strife",

                    // Film Karakterleri
                    "Harry Potter", "Hermione Granger", "Ron Weasley", "Darth Vader", "Luke Skywalker",
                    "Han Solo", "Yoda", "Frodo Baggins", "Gandalf", "Aragorn",
                    "Legolas", "Gollum", "Batman", "Superman", "Wonder Woman",
                    "Iron Man", "Captain America", "Hulk", "Thor", "Black Widow",
                    "Spider-Man", "Joker", "Harley Quinn", "Deadpool", "Wolverine",

                    // Çizgi Film / Animasyon
                    "Mickey Mouse", "Donald Duck", "Goofy", "Bugs Bunny", "Daffy Duck",
                    "Homer Simpson", "Bart Simpson", "Marge Simpson", "Lisa Simpson", "Maggie Simpson",
                    "SpongeBob SquarePants", "Patrick Star", "Squidward", "Shrek", "Donkey",
                    "Fiona", "Po (Kung Fu Panda)", "Master Shifu", "Simba", "Mufasa",

                    // Yazarlar
                    "Orhan Pamuk", "Yaşar Kemal", "Nazım Hikmet", "Elif Şafak", "J.K. Rowling",
                    "J.R.R. Tolkien", "George R.R. Martin", "William Shakespeare", "Stephen King", "Agatha Christie",

                    // Diğer sporcular
                    "Roger Federer", "Rafael Nadal", "Novak Djokovic", "Serena Williams", "Usain Bolt",
                    "Muhammad Ali", "Mike Tyson", "Lewis Hamilton", "Michael Schumacher", "Valentino Rossi",

                    // Teknoloji figürleri
                    "Steve Jobs", "Bill Gates", "Mark Zuckerberg", "Elon Musk", "Jeff Bezos",
                    "Larry Page", "Sergey Brin", "Sundar Pichai", "Tim Cook", "Satya Nadella",

                    // Türk ünlüler (ekstra)
                    "Beren Saat", "Hande Erçel", "Burak Özçivit", "Engin Akyürek", "Kenan İmirzalioğlu",
                    "Halit Ergenç", "Bergüzar Korel", "Meryem Uzerli", "Demet Akbağ", "Ata Demirer",

                    // Ekstra uluslararası
                    "Oprah Winfrey", "Ellen DeGeneres", "Jimmy Fallon", "David Letterman", "Trevor Noah",
                    "Kim Kardashian", "Kanye West", "Drake", "Justin Bieber", "Selena Gomez"
                ]
                return pool.randomElement() ?? "word pool back"
            case .custom:
                return settings.customWord?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? settings.customWord!.trimmingCharacters(in: .whitespacesAndNewlines)
                : "word pool back"
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

        // Seçili olmayan herkesin role'ünü temizle (isteğe bağlı)
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

        // Oda info
        // random sıra oluştur
        let turnOrder = selectedIds.shuffled()

        // Oda info
        var info: [String:Any] = [
            "status": "the game",
            "word": word,
            "spyCount": spyCount,
            "totalRounds": settings.totalRounds,
            "lockedPlayers": selectedIds,
            "turnOrder": turnOrder
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
