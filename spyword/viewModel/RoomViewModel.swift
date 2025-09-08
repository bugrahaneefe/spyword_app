import SwiftUI
import Firebase

struct GameSettings {
    enum WordMode { case random, custom }
    enum WordCategory: String, CaseIterable {
        case world
        case turkiye
        case worldFootball
        case nfl
        case movies
        case science
        case history
        case geography
        case music
        case literature
    }

    var mode: WordMode
    var customWord: String?
    var spyCount: Int
    var totalRounds: Int
    var category: WordCategory
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

            let info: [String:Any] = [
                "status": "the game",
                "word": word,
                "spyCount": spyCount,
                "totalRounds": settings.totalRounds,
                "lockedPlayers": selectedIds,
                "turnOrder": turnOrder,
                "category": settings.category.rawValue
            ]

            batch.setData(["info": info], forDocument: roomRef, merge: true)

            batch.commit { [weak self] error in
                if let err = error {
                    DispatchQueue.main.async { self?.errorMessage = err.localizedDescription }
                }
            }
        }

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
        case .movies:        pool = movies
        case .science:       pool = science
        case .history:       pool = history
        case .geography:     pool = geography
        case .music:         pool = music
        case .literature:    pool = literature
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
    
    // 5) MOVIES – 50 (ünlü filmler & karakterler)
    static let movies: [String] = [
        "The Godfather","Titanic","Inception","The Matrix","Forrest Gump",
        "The Dark Knight","Avatar","Pulp Fiction","Gladiator","Interstellar",
        "Joker","Avengers","Toy Story","Frozen","Finding Nemo",
        "Star Wars","Lord of the Rings","Jurassic Park","Shrek","The Lion King",
        "Harry Potter","Spider-Man","Batman","Superman","Iron Man",
        "Black Panther","Wonder Woman","Doctor Strange","Guardians of the Galaxy","Thor",
        "Hulk","Captain America","Ant-Man","Deadpool","Wolverine",
        "X-Men","The Shawshank Redemption","Fight Club","Se7en","The Silence of the Lambs",
        "The Green Mile","The Prestige","Django Unchained","The Departed","Whiplash",
        "La La Land","Coco","Up","Inside Out","Soul"
    ]

    // 6) SCIENCE – 50 (bilim insanları & kavramlar)
    static let science: [String] = [
        "Albert Einstein","Isaac Newton","Nikola Tesla","Galileo Galilei","Marie Curie",
        "Charles Darwin","Stephen Hawking","Richard Feynman","Carl Sagan","Niels Bohr",
        "Dmitri Mendeleev","Gregor Mendel","Alan Turing","Rosalind Franklin","Ada Lovelace",
        "Michael Faraday","James Clerk Maxwell","Louis Pasteur","Robert Hooke","Max Planck",
        "Erwin Schrödinger","Werner Heisenberg","Enrico Fermi","Paul Dirac","J.J. Thomson",
        "Ernest Rutherford","Francis Crick","James Watson","Higgs boson","Quantum Mechanics",
        "Relativity","DNA","RNA","Photosynthesis","Evolution",
        "Black Hole","Big Bang","Gravity","Atom","Molecule",
        "Cell","Neuron","Genome","Periodic Table","Electricity",
        "Magnetism","Light","Laser","Microscope","Telescope"
    ]

    // 7) HISTORY – 50 (tarihi şahsiyetler & olaylar)
    static let history: [String] = [
        "Alexander the Great","Julius Caesar","Napoleon Bonaparte","Genghis Khan","Cleopatra",
        "Winston Churchill","Abraham Lincoln","George Washington","Mahatma Gandhi","Mustafa Kemal Atatürk",
        "Nelson Mandela","Martin Luther King Jr.","Queen Elizabeth I","Adolf Hitler","Joseph Stalin",
        "Vladimir Lenin","Franklin D. Roosevelt","John F. Kennedy","Ronald Reagan","Barack Obama",
        "Donald Trump","Angela Merkel","Margaret Thatcher","Suleiman the Magnificent","Charlemagne",
        "Leonardo da Vinci","Michelangelo","Christopher Columbus","Ferdinand Magellan","Marco Polo",
        "Albert Einstein","Isaac Newton","Nikola Tesla","Marie Curie","Galileo Galilei",
        "French Revolution","American Revolution","Industrial Revolution","World War I","World War II",
        "Cold War","Fall of Berlin Wall","Crusades","Renaissance","Reformation",
        "Great Depression","Black Death","Battle of Waterloo","Signing of Magna Carta","Moon Landing"
    ]

    // 8) GEOGRAPHY – 50 (şehirler, ülkeler, coğrafi yerler)
    static let geography: [String] = [
        "Istanbul","Ankara","Izmir","London","Paris",
        "New York","Los Angeles","Tokyo","Kyoto","Beijing",
        "Shanghai","Moscow","Berlin","Rome","Madrid",
        "Barcelona","Lisbon","Cairo","Cape Town","Nairobi",
        "Rio de Janeiro","São Paulo","Buenos Aires","Mexico City","Toronto",
        "Sydney","Melbourne","Auckland","Dubai","Abu Dhabi",
        "Jerusalem","Mecca","Mount Everest","K2","Andes",
        "Himalayas","Sahara Desert","Amazon Rainforest","Nile River","Danube River",
        "Mississippi River","Great Wall of China","Grand Canyon","Niagara Falls","Eiffel Tower",
        "Big Ben","Statue of Liberty","Colosseum","Machu Picchu","Petra"
    ]

    // 9) MUSIC – 50 (ünlü şarkıcılar & gruplar)
    static let music: [String] = [
        "The Beatles","The Rolling Stones","Queen","Pink Floyd","Led Zeppelin",
        "Nirvana","Metallica","U2","Coldplay","Radiohead",
        "Maroon 5","Imagine Dragons","OneRepublic","Linkin Park","Green Day",
        "Taylor Swift","Beyoncé","Rihanna","Katy Perry","Lady Gaga",
        "Adele","Ed Sheeran","Justin Bieber","Billie Eilish","Shakira",
        "Jennifer Lopez","Madonna","Britney Spears","Christina Aguilera","Whitney Houston",
        "Elvis Presley","Michael Jackson","Prince","Bob Dylan","Bruce Springsteen",
        "Eminem","Drake","Kanye West","Jay-Z","Kendrick Lamar",
        "Travis Scott","Post Malone","Harry Styles","Dua Lipa","Selena Gomez",
        "Ariana Grande","The Weeknd","Bruno Mars","Snoop Dogg","50 Cent"
    ]

    // 10) LITERATURE – 50 (yazarlar & kitap karakterleri)
    static let literature: [String] = [
        "William Shakespeare","Charles Dickens","Jane Austen","George Orwell","Mark Twain",
        "J.K. Rowling","J.R.R. Tolkien","C.S. Lewis","Agatha Christie","Leo Tolstoy",
        "Fyodor Dostoevsky","Anton Chekhov","Homer","Virgil","Dante Alighieri",
        "Victor Hugo","Gabriel García Márquez","Franz Kafka","Ernest Hemingway","F. Scott Fitzgerald",
        "Harper Lee","John Steinbeck","Stephen King","Arthur Conan Doyle","Edgar Allan Poe",
        "Emily Brontë","Charlotte Brontë","Mary Shelley","Oscar Wilde","H.G. Wells",
        "George R.R. Martin","Suzanne Collins","Rick Riordan","Dan Brown","Paulo Coelho",
        "Harry Potter","Hermione Granger","Ron Weasley","Sherlock Holmes","Dr. Watson",
        "Jay Gatsby","Holden Caulfield","Atticus Finch","Anna Karenina","Elizabeth Bennet",
        "Romeo","Juliet","Hamlet","Macbeth","Don Quixote"
    ]
}
