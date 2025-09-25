import SwiftUI
import Firebase

struct GameSettings {
    enum WordMode { case random, custom }
    enum WordCategory: String, CaseIterable {
        case world, worldFootball, nfl, movies, science, history, geography, music, literature, technology, mythology, festivals, cuisine
        case turkiye, trInfluencers, trPoliticians, trMemes, trStreetFood, trActors
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
        
        var info: [String:Any] = [
            "status": "the game",
            "word": word,
            "spyCount": spyCount,
            "totalRounds": settings.totalRounds,
            "lockedPlayers": selectedIds,
            "turnOrder": turnOrder
        ]
        
        if settings.mode == .random {
            info["category"] = settings.category.rawValue
        } else {
            info["category"] = "custom"
        }
        
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
        case .technology:    pool = technology
        case .mythology:     pool = mythology
        case .festivals:     pool = festivals
        case .cuisine:       pool = cuisine
        case .trInfluencers: pool = trInfluencers
        case .trPoliticians: pool = trPoliticians
        case .trMemes:       pool = trMemes
        case .trStreetFood:  pool = trStreetFood
        case .trActors: pool = trActors
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
    
    static let movies: [String] = [
        "Vito Corleone",
        "Jack Dawson",
        "Dom Cobb",
        "Neo",
        "Forrest Gump",
        "Batman",
        "Jake Sully",
        "Vincent Vega",
        "Maximus",
        "Cooper",
        "Joker",
        "Iron Man",
        "Woody",
        "Elsa",
        "Nemo",
        "Luke Skywalker",
        "Frodo Baggins",
        "Dr. Alan Grant",
        "Shrek",
        "Simba",
        "Harry Potter",
        "Spider-Man",
        "Batman",
        "Superman",
        "Iron Man",
        "Black Panther",
        "Wonder Woman",
        "Doctor Strange",
        "Star-Lord",
        "Thor",
        "Hulk",
        "Captain America",
        "Ant-Man",
        "Deadpool",
        "Wolverine",
        "Professor X",
        "Andy Dufresne",
        "Tyler Durden",
        "Detective Mills",
        "Hannibal Lecter",
        "John Coffey",
        "Robert Angier",
        "Django",
        "Billy Costigan",
        "Andrew Neiman",
        "Mia Dolan",
        "Miguel",
        "Carl Fredricksen",
        "Joy",
        "Joe Gardner"
    ]


    // 6) SCIENCE – 50 (bilim insanları & kavramlar)
    static let science: [String] = [
        "Albert Einstein","Isaac Newton","Nikola Tesla","Galileo Galilei","Marie Curie",
        "Charles Darwin","Stephen Hawking","Richard Feynman","Carl Sagan","Niels Bohr",
        "Dmitri Mendeleev","Gregor Mendel","Alan Turing","Rosalind Franklin","Ada Lovelace",
        "Michael Faraday","James Clerk Maxwell","Louis Pasteur","Robert Hooke","Max Planck",
        "Erwin Schrödinger","Werner Heisenberg","Enrico Fermi","Paul Dirac","J.J. Thomson",
        "Ernest Rutherford","Francis Crick","James Watson"
    ]

    // 7) HISTORY – 50 (tarihi şahsiyetler & olaylar)
    static let history: [String] = [
        "Alexander the Great","Julius Caesar","Napoleon Bonaparte","Genghis Khan","Cleopatra",
        "Winston Churchill","Abraham Lincoln","George Washington","Mahatma Gandhi","Mustafa Kemal Atatürk",
        "Nelson Mandela","Martin Luther King Jr.","Queen Elizabeth I","Adolf Hitler","Joseph Stalin",
        "Vladimir Lenin","Franklin D. Roosevelt","John F. Kennedy","Ronald Reagan","Barack Obama",
        "Donald Trump","Angela Merkel","Margaret Thatcher","Suleiman the Magnificent","Charlemagne",
        "Leonardo da Vinci","Michelangelo","Christopher Columbus","Ferdinand Magellan","Marco Polo",
        "Albert Einstein","Isaac Newton","Nikola Tesla","Marie Curie","Galileo Galilei"
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
    
    // 11) TECHNOLOGY – 50 (global tech kavramları)
    static let technology: [String] = [
        "Steve Jobs",            // Smartphone, Apple
        "Tim Berners-Lee",       // Internet (World Wide Web)
        "Geoffrey Hinton",       // Artificial Intelligence pioneer
        "Satoshi Nakamoto",      // Blockchain / Bitcoin
        "John Preskill",         // Quantum Computing
        "Marc Andreessen",       // Cloud Computing, Netscape/VC influence
        "Ajit Pai",              // 5G (FCC policy figure)
        "Hedy Lamarr",           // Wi-Fi co-inventor
        "Bradford Parkinson",    // GPS creator
        "Frank Wang",            // DJI founder, Drone industry leader
        "Isaac Asimov",          // Robotics visionary (laws of robotics)
        "Andrew Ng",             // Machine Learning
        "Palmer Luckey",         // Virtual Reality (Oculus)
        "Tim Sweeney",           // Augmented Reality / Unreal Engine
        "Eugene Kaspersky",      // Cybersecurity
        "Whitfield Diffie",      // Encryption pioneer
        "Jack Kilby",            // Microchip
        "Morris Chang",          // Semiconductor industry (TSMC)
        "John B. Goodenough",    // Lithium-ion Battery
        "Elon Musk",             // Solar, EVs, SpaceX
        "James Dyson",           // Electric Vehicle / Engineering innovations
        "Chuck Hull",            // 3D Printing inventor
        "Richard Feynman",       // Nanotechnology visionary
        "Richard Stallman",      // Open Source
        "Linus Torvalds",        // Linux creator
        "Chris Wanstrath",       // GitHub co-founder
        "Reed Hastings",         // Streaming (Netflix)
        "Adam Curry",            // Podcast pioneer
        "James Park",            // Smartwatch/Wearables (Fitbit)
        "Kevin Ashton",          // Internet of Things (coined the term)
        "Jeff Bezos",            // Smart Home (Alexa)
        "Dag Kittlaus",          // Voice Assistant (Siri co-creator)
        "E.A. Johnson",          // Touchscreen pioneer
        "Ajay Bhatt",            // USB creator (USB-C legacy)
        "Mark Kryder",           // Solid State Drive
        "Jensen Huang",          // GPU (NVIDIA)
        "Gordon Moore",          // CPU (Intel co-founder)
        "Leonard Kleinrock",     // Router / Internet protocols
        "John Cioffi",           // Modem DSL father
        "Michael Dell",          // Data Centers
        "Roy Fielding",          // API & REST
        "Edgar F. Codd",         // Database (relational model)
        "Ada Lovelace",          // Algorithm pioneer
        "Clive Humby",           // Big Data quote “data is the new oil”
        "Marc Benioff",          // SaaS (Salesforce)
        "Solomon Hykes",         // Containerization (Docker)
        "Brendan Burns",         // Kubernetes co-creator
        "Solomon Hykes",         // Docker founder
        "Satya Nadella"          // Edge Computing, Microsoft Azure
    ]

    // 13) MYTHOLOGY – 50 (çok kültürlü mitoloji & folklor)
    static let mythology: [String] = [
        "Zeus","Hera","Poseidon","Athena","Ares",
        "Apollo","Artemis","Hades","Hermes","Aphrodite",
        "Hephaestus","Dionysus","Odin","Thor","Loki",
        "Freya","Tyr","Balder","Heimdall","Ra",
        "Osiris","Isis","Anubis","Horus","Bastet",
        "Shiva","Vishnu","Brahma","Ganesha","Kali",
        "Amaterasu","Susanoo","Tsukuyomi","Quetzalcoatl","Tezcatlipoca",
        "Kukulkan","Fenrir","Medusa","Minotaur","Pegasus",
        "Kraken","Phoenix","Dragon","Griffin","Hydra",
        "Jinn","Baba Yaga","Raven","Coyote","Yeti"
    ]
    
    static let festivals: [String] = [
        "Julius Caesar",
        "Emperor Wu of Han",
        "Lakshmi",
        "Krishna",
        "Jesus Christ",
        "Judah Maccabee",
        "Jesus Christ",
        "Moses",
        "Zoroaster",
        "Buddha",
        "Mictecacihuatl",
        "Various Saints",
        "Dionysus",
        "King Ludwig I",
        "Indra",
        "Chang’e",
        "Gautama Buddha",
        "Yu the Great",
        "Qu Yuan",
        "Murugan",
        "Shiva",
        "Dangun",
        "Emperor Hung Kings",
        "Saint Patrick",
        "Saint Valentine",
        "Celtic Druids",
        "Pilgrims & Native Leaders",
        "Thomas Jefferson",
        "Marsha P. Johnson",
        "Spanish Villagers",
        "Buddha",
        "San Fermín",
        "Scottish Clans",
        "Guy Fawkes",
        "Doge of Venice",
        "Chinese Emperors",
        "Kyoto Nobles",
        "Lumière Brothers",
        "Michael Eavis",
        "Larry Harvey",
        "Paul Tollett",
        "Fyodor Dostoevsky",
        "Latvian Choral Leaders",
        "Santo Niño",
        "Vikings",
        "Carioca Samba Schools",
        "Emperor Saga",
    ]

    // 15) CUISINE – 50 (dünya mutfaklarından yemek/öğe)
    static let cuisine: [String] = [
        "Pizza","Sushi","Tacos","Paella","Pho",
        "Ramen","Kimchi","Bibimbap","Curry","Biryani",
        "Pad Thai","Dim Sum","Peking Duck","Falafel","Hummus",
        "Shawarma","Kebab","Baklava","Tiramisu","Gelato",
        "Croissant","Baguette","Cheese Fondue","Schnitzel","Goulash",
        "Pierogi","Borscht","Fish and Chips","Roast Beef","Apple Pie",
        "Burrito","Arepa","Empanada","Ceviche","Feijoada",
        "Churrasco","Poutine","Pancakes","Chow Mein","Fried Rice",
        "Satay","Laksa","Tom Yum","Nasi Goreng","Samosa",
        "Naan","Tortilla","Couscous","Jollof Rice","Injera"
    ]
    
    // 16) TÜRKİYE – SOSYAL MEDYA ÜNLÜLERİ (influencer/streamer/creator)
    static let trInfluencers: [String] = [
        "Enes Batur","Reynmen","Danla Bilic","Orkun Işıtmak","Berkcan Güven",
        "Ruhi Çenet","Barış Özcan","Uras Benlioğlu","Alper Rende","Meryem Can",
        "Merve Özkaynak","Duygu Köseoğlu","Oğuzhan Uğur","Emre Durmuş","Yorekok",
        "CZN Burak","Nusret","Kerimcan Durmaz","Mithrain","wtcnn",
        "Elraenn","Jahrein","Pqueen","Unlost","Efe Uygaç",
        "Batu Akdeniz","Kafalar","Deli Mi Ne","Varol Şahin","Murat Soner",
        "Doğan Kabak","Alfa","Doğanay","Büşra Pekin","Burak Güngör",
        "Ahmet Şengül","Zeynep Bastık","Berkcan","Fester Abdü","Babala TV",
        "Barış G","Burak Oyunda","Hepimiz Biriz","Boran Kuzum","Merve Boluğur"
    ]

    // 17) TÜRKİYE – SİYASETÇİLER (tarih + güncel)
    static let trPoliticians: [String] = [
        "Mustafa Kemal Atatürk","İsmet İnönü","Süleyman Demirel","Bülent Ecevit","Turgut Özal",
        "Mesut Yılmaz","Necmettin Erbakan","Alparslan Türkeş","Tansu Çiller","Devlet Bahçeli",
        "Recep Tayyip Erdoğan","Abdullah Gül","Ahmet Davutoğlu","Ali Babacan","Binali Yıldırım",
        "Süleyman Soylu","Kemal Kılıçdaroğlu","Özgür Özel","Meral Akşener","Ümit Özdağ",
        "Sinan Oğan","Doğu Perinçek","Temel Karamollaoğlu","Selahattin Demirtaş","Pervin Buldan",
        "Ekrem İmamoğlu","Mansur Yavaş","Melih Gökçek","Kadir Topbaş","Ahmet Necdet Sezer",
        "Rauf Denktaş","Deniz Baykal","İsmail Cem","Hikmet Çetin","Mehmet Ali Şahin",
        "Nurettin Nebati","Berat Albayrak","Fuat Oktay","Numan Kurtulmuş","Bekir Bozdağ",
        "Mevlüt Çavuşoğlu","Hakan Fidan","Yılmaz Büyükerşen","Abdüllatif Şener","İlhan Kesici"
    ]
    
    static let trActors: [String] = [
        "Kıvanç Tatlıtuğ",
        "Engin Akyürek",
        "Burak Özçivit",
        "Çağatay Ulusoy",
        "Kenan İmirzalıoğlu",
        "Halit Ergenç",
        "Tuba Büyüküstün",
        "Beren Saat",
        "Bergüzar Korel",
        "Hazal Kaya",
        "Serenay Sarıkaya",
        "Demet Özdemir",
        "Elçin Sangu",
        "Hande Erçel",
        "Neslihan Atagül",
        "Fahriye Evcen",
        "Meryem Uzerli",
        "Songül Öden",
        "Oktay Kaynarca",
        "Haluk Bilginer"
    ]

    // 18) TÜRKİYE – İNTERNET KÜLTÜRÜ & MİZAH (meme/ikonik ifade & yer)
    static let trMemes: [String] = [
        "Kadıköy Boğası","Beyaz Show","Recep İvedik",
        "İbo Show","Testo Taylan","Derbeder Berk","Konsol Oyun",
        "Konyalı John Wick","Erşan Kuneri","Behlül","Garip Kont",
        "Ezel","Behzat Ç.","Süleyman Çakır","Polat Alemdar","Saniye",
        "Altın Çocuk","Hayrettin","Kadir Hoca"
    ]

    // 19) TÜRKİYE – SOKAK LEZZETLERİ (yerel & ikonik)
    static let trStreetFood: [String] = [
        "Simit","Çay","Döner","Lahmacun","Kokoreç",
        "Midye Dolma","Islak Hamburger","Tantuni","Pilav Üstü Tavuk","Kumpir",
        "Balık Ekmek","Çiğ Köfte","Kelle Paça","Mercimek Çorbası","İskender",
        "Kuzu Çevirme","Adana Dürüm","Urfa Dürüm","Pide","Künefe",
        "Katmer","Süt Mısır","Boza","Ayran","Şalgam",
        "Atom Kokteyl","Nohut Dürüm","Börek","Boyoz","Gözleme",
        "Kestane","Sahlep","Kokoreç Yarım","Ciğer Şiş","Sokak Dondurması",
        "Halka Tatlısı","Lokma","Akçaabat Köfte","Islama Köfte","Çubuk Turşu",
        "Kokoreç Tırnak","Tavuklu Pilav","Sütlaç","Turan Tava","Atom Midye"
    ]
}
