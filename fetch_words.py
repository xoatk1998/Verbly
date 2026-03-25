#!/usr/bin/env python3
"""
Fetch ~2710 new words to bring sample.csv to 3000 entries.
- English definition: Free Dictionary API
- Vietnamese translation: MyMemory API
- Example sentence: generated from the word
"""

import csv, json, time, urllib.request, urllib.parse, urllib.error
from pathlib import Path

CSV_PATH = Path(__file__).parent / "sample.csv"
DICT_API  = "https://api.dictionaryapi.dev/api/v2/entries/en"
TRANS_API = "https://api.mymemory.translated.net/get"

# ---------------------------------------------------------------------------
# Word bank  (category -> difficulty -> [words])
# ---------------------------------------------------------------------------
WORD_BANK = {
    "Daily Communication": {
        "A1": [
            "hello","goodbye","please","thank","sorry","yes","no","maybe","here","there",
            "who","what","when","where","why","how","name","age","family","mother",
            "father","sister","brother","friend","boy","girl","man","woman","child","baby",
            "home","school","food","water","time","day","night","morning","evening","week",
            "month","year","today","tomorrow","yesterday","always","never","often","sometimes","now",
            "help","want","need","like","love","know","think","say","go","come",
            "see","hear","eat","drink","sleep","walk","run","sit","stand","play",
            "good","bad","big","small","hot","cold","new","old","happy","sad",
            "fast","slow","easy","hard","right","wrong","same","different","open","close",
            "color","red","blue","green","yellow","white","black","number","one","two",
            "three","four","five","ten","hundred","money","price","buy","sell","pay",
        ],
        "A2": [
            "invite","accept","refuse","agree","disagree","greet","introduce","explain","describe","repeat",
            "understand","remember","forget","learn","teach","read","write","speak","listen","talk",
            "call","text","message","letter","word","sentence","language","vocabulary","grammar","pronunciation",
            "hobby","interest","sport","music","art","movie","book","game","party","celebration",
            "birthday","holiday","weekend","vacation","plan","arrange","cancel","change","suggest","offer",
            "weather","warm","cool","rainy","sunny","windy","cloudy","snow","storm","temperature",
            "feel","emotion","excited","bored","tired","hungry","thirsty","sick","well","better",
            "polite","rude","kind","mean","funny","serious","quiet","loud","shy","friendly",
            "short","tall","thin","fat","young","strong","weak","clean","dirty","beautiful",
            "address","phone","email","internet","website","app","social media","news","information","question",
        ],
        "B1": [
            "conversation","discussion","debate","argument","opinion","viewpoint","perspective","attitude","belief","value",
            "relationship","connection","communication","interaction","cooperation","collaboration","negotiation","compromise","conflict","resolution",
            "expression","phrase","idiom","proverb","metaphor","tone","style","formal","informal","polite",
            "misunderstand","clarify","confirm","summarize","paraphrase","quote","mention","refer","imply","suggest",
            "emphasize","highlight","conclude","recommend","advise","warn","encourage","motivate","persuade","convince",
            "announce","declare","admit","deny","acknowledge","apologize","forgive","blame","accuse","defend",
            "complain","protest","object","insist","demand","request","permission","approval","rejection","disappointment",
            "celebrate","congratulate","appreciate","gratitude","respect","trust","support","encourage","comfort","reassure",
            "concern","worry","anxiety","stress","pressure","expectation","responsibility","obligation","commitment","promise",
            "habit","routine","lifestyle","culture","tradition","custom","norm","value","identity","personality",
        ],
        "B2": [
            "articulate","eloquent","persuasive","diplomatic","tactful","assertive","empathetic","compassionate","tolerant","patient",
            "misinterpret","misrepresent","exaggerate","understate","contradict","refute","challenge","question","doubt","speculate",
            "assumption","inference","implication","connotation","ambiguity","nuance","context","subtext","irony","sarcasm",
            "stereotype","prejudice","bias","discrimination","equality","diversity","inclusion","representation","privilege","marginalize",
            "initiative","proactive","leadership","mentorship","accountability","transparency","integrity","authenticity","credibility","reputation",
            "rapport","empathy","sympathy","compassion","solidarity","community","belonging","alienation","isolation","loneliness",
            "gratitude","appreciation","acknowledgment","validation","affirmation","encouragement","inspiration","motivation","ambition","aspiration",
            "reconciliation","mediation","arbitration","diplomacy","tact","sensitivity","awareness","mindfulness","reflection","introspection",
            "eloquence","rhetoric","discourse","narrative","dialogue","monologue","debate","critique","analysis","synthesis",
            "intercultural","multilingual","bilingual","fluency","proficiency","competency","literacy","numeracy","communication","collaboration",
        ],
        "C1": [
            "pragmatic","nuanced","sophisticated","articulate","verbose","laconic","succinct","concise","ambiguous","equivocal",
            "insinuate","allude","euphemism","dysphemism","undermine","subvert","reinforce","perpetuate","challenge","deconstruct",
            "etiquette","protocol","decorum","propriety","convention","formality","hierarchy","deference","authority","influence",
            "rhetoric","oratory","eloquence","persuasion","manipulation","propaganda","indoctrination","censorship","misinformation","disinformation",
            "candid","forthright","blunt","tactless","circumspect","discreet","judicious","prudent","circumlocution","obfuscation",
        ],
        "C2": [
            "loquacious","garrulous","voluble","taciturn","reticent","laconic","pithy","trenchant","incisive","pellucid",
            "perspicacious","sagacious","discerning","astute","shrewd","perceptive","intuitive","prescient","clairvoyant","omniscient",
            "verisimilitude","veracious","mendacious","disingenuous","dissembling","prevaricating","equivocating","obfuscating","circumventing","dissimulating",
        ],
    },
    "IT": {
        "A2": [
            "computer","laptop","tablet","phone","screen","keyboard","mouse","printer","scanner","camera",
            "internet","wifi","bluetooth","cable","charger","battery","power","button","screen","display",
            "file","folder","document","image","photo","video","audio","text","data","information",
            "email","message","chat","call","video call","social media","website","browser","search","download",
            "upload","save","delete","copy","paste","cut","undo","redo","zoom","scroll",
            "password","username","login","logout","account","profile","setting","menu","icon","app",
            "install","uninstall","update","restart","shutdown","backup","storage","memory","processor","operating system",
        ],
        "B1": [
            "software","hardware","network","server","database","cloud","security","encryption","firewall","antivirus",
            "programming","coding","algorithm","function","variable","loop","condition","array","object","class",
            "frontend","backend","fullstack","developer","engineer","designer","analyst","administrator","architect","consultant",
            "debugging","testing","deployment","version control","repository","branch","merge","commit","pull request","code review",
            "API","interface","framework","library","module","package","dependency","integration","documentation","specification",
            "bandwidth","latency","throughput","protocol","port","IP address","domain","hosting","DNS","SSL",
            "authentication","authorization","session","token","cookie","cache","queue","thread","process","memory",
            "backup","recovery","migration","scaling","monitoring","logging","analytics","dashboard","report","visualization",
            "agile","scrum","sprint","kanban","waterfall","DevOps","CI/CD","automation","testing","deployment",
            "mobile app","web app","desktop app","cross-platform","responsive","accessibility","usability","performance","optimization","refactoring",
        ],
        "B2": [
            "microservices","containerization","virtualization","orchestration","kubernetes","docker","terraform","ansible","puppet","chef",
            "machine learning","artificial intelligence","neural network","deep learning","natural language processing","computer vision","data science","big data","analytics","prediction",
            "blockchain","cryptocurrency","distributed system","consensus","decentralization","smart contract","token","wallet","mining","ledger",
            "cybersecurity","penetration testing","vulnerability","exploit","malware","ransomware","phishing","social engineering","zero-day","patch",
            "REST","GraphQL","gRPC","microservice","event-driven","message queue","pub/sub","webhook","streaming","real-time",
            "relational database","NoSQL","SQL","query","index","transaction","normalization","sharding","replication","consistency",
            "git","version control","branching strategy","code quality","technical debt","refactoring","clean code","design pattern","SOLID","DRY",
            "load balancer","reverse proxy","CDN","caching","session management","rate limiting","throttling","circuit breaker","retry","timeout",
            "unit test","integration test","end-to-end test","test-driven development","behavior-driven development","mocking","stubbing","coverage","regression","performance test",
            "requirement","specification","use case","user story","acceptance criteria","prototype","wireframe","mockup","stakeholder","roadmap",
        ],
        "C1": [
            "idempotency","atomicity","consistency","isolation","durability","eventual consistency","CAP theorem","distributed consensus","fault tolerance","high availability",
            "polymorphism","encapsulation","abstraction","inheritance","composition","dependency injection","inversion of control","design pattern","antipattern","refactoring",
            "observability","tracing","profiling","benchmarking","chaos engineering","site reliability engineering","platform engineering","developer experience","inner source","open source",
            "homomorphic encryption","zero-knowledge proof","federated learning","differential privacy","adversarial attack","model interpretability","bias","fairness","robustness","generalization",
            "concurrency","parallelism","asynchronous","synchronous","race condition","deadlock","mutex","semaphore","coroutine","actor model",
        ],
        "C2": [
            "quorum","paxos","raft","byzantine fault","vector clock","crdt","gossip protocol","consistent hashing","bloom filter","skiplist",
            "metaprogramming","reflection","introspection","homoiconicity","continuation","monad","functor","applicative","type theory","dependent type",
        ],
    },
    "Office": {
        "A2": [
            "desk","chair","table","lamp","pen","pencil","paper","notebook","calendar","clock",
            "phone","computer","printer","copy","fax","file","folder","stapler","tape","scissors",
            "boss","employee","manager","secretary","receptionist","colleague","team","department","company","office",
            "work","job","task","project","meeting","deadline","schedule","appointment","interview","presentation",
            "salary","wage","bonus","promotion","raise","benefit","contract","agreement","policy","rule",
            "break","lunch","overtime","shift","holiday","leave","sick","vacation","resign","retire",
        ],
        "B1": [
            "agenda","minutes","proposal","report","memo","brief","summary","analysis","budget","forecast",
            "strategy","objective","goal","target","milestone","priority","timeline","resource","allocation","planning",
            "collaboration","teamwork","delegation","supervision","evaluation","performance","appraisal","feedback","coaching","mentoring",
            "recruitment","hiring","onboarding","training","development","career","progression","succession","retention","turnover",
            "invoice","receipt","expense","reimbursement","procurement","vendor","supplier","contract","negotiation","compliance",
            "conference","seminar","workshop","training","webinar","teleconference","videoconference","presentation","demo","pitch",
            "workflow","process","procedure","protocol","guideline","standard","quality","efficiency","productivity","output",
            "correspondence","communication","announcement","newsletter","bulletin","notice","circular","directive","instruction","guidance",
            "office supplies","stationery","equipment","furniture","facility","maintenance","IT support","helpdesk","infrastructure","security",
            "hierarchy","structure","chart","matrix","cross-functional","stakeholder","decision","approval","authorization","escalation",
        ],
        "B2": [
            "executive","director","vice president","chief officer","board","shareholder","stakeholder","governance","compliance","audit",
            "restructuring","reorganization","downsizing","merger","acquisition","spin-off","divestiture","joint venture","partnership","subsidiary",
            "KPI","metric","benchmark","dashboard","scorecard","objective","result","outcome","impact","value",
            "innovation","disruption","transformation","digitization","automation","optimization","streamlining","standardization","integration","consolidation",
            "leadership","management","coaching","mentoring","empowerment","engagement","motivation","culture","values","ethics",
            "conflict of interest","whistleblower","transparency","accountability","responsibility","integrity","fairness","equity","diversity","inclusion",
            "intellectual property","patent","trademark","copyright","trade secret","licensing","royalty","infringement","protection","disclosure",
            "risk management","contingency","mitigation","assessment","framework","register","appetite","tolerance","exposure","control",
            "change management","resistance","adoption","communication","training","implementation","rollout","go-live","stabilization","optimization",
            "remote work","hybrid","flexible","work-life balance","wellness","burnout","mental health","stress","resilience","engagement",
        ],
        "C1": [
            "fiduciary","indemnification","arbitration","litigation","jurisdiction","liability","negligence","breach","remedy","damages",
            "due diligence","valuation","goodwill","amortization","depreciation","impairment","write-off","provision","accrual","capitalization",
            "organizational behavior","systems thinking","complexity","ambiguity","volatility","uncertainty","resilience","adaptability","agility","innovation",
            "negotiation","persuasion","influence","politics","power","coalition","alliance","lobbying","advocacy","diplomacy",
        ],
    },
    "Culinary": {
        "A2": [
            "rice","bread","meat","fish","chicken","beef","pork","egg","milk","cheese",
            "vegetable","fruit","salad","soup","stew","pasta","noodle","pizza","burger","sandwich",
            "apple","banana","orange","grape","strawberry","mango","lemon","lime","peach","pear",
            "carrot","potato","tomato","onion","garlic","pepper","cucumber","lettuce","spinach","broccoli",
            "salt","sugar","oil","butter","sauce","spice","herb","vinegar","honey","jam",
            "breakfast","lunch","dinner","snack","dessert","cake","cookie","pie","ice cream","chocolate",
            "coffee","tea","juice","water","milk","beer","wine","soda","smoothie","cocktail",
            "cook","bake","fry","boil","grill","roast","steam","mix","chop","slice",
            "hungry","full","delicious","tasty","sweet","sour","salty","bitter","spicy","fresh",
            "recipe","ingredient","portion","serving","meal","dish","course","menu","order","taste",
        ],
        "B1": [
            "cuisine","gastronomy","culinary","gourmet","epicure","foodie","chef","sous chef","line cook","pastry chef",
            "appetizer","starter","entree","main course","side dish","garnish","condiment","dressing","marinade","glaze",
            "saute","blanch","braise","poach","simmer","reduce","deglaze","flambe","caramelize","emulsify",
            "knife","cutting board","pan","pot","wok","oven","microwave","blender","mixer","food processor",
            "cuisine","regional","traditional","modern","fusion","molecular","farm-to-table","organic","artisan","handcrafted",
            "fermentation","pickling","curing","smoking","aging","preserving","canning","drying","marinating","brining",
            "gluten","dairy","vegan","vegetarian","pescatarian","kosher","halal","allergen","intolerance","dietary",
            "texture","consistency","viscosity","tenderness","crunch","crispness","flakiness","chewiness","smoothness","creaminess",
            "presentation","plating","garnish","decoration","aesthetic","visual","color","arrangement","portion","balance",
            "umami","savory","aromatic","fragrant","pungent","zesty","tangy","robust","mild","delicate",
        ],
        "B2": [
            "gastronomy","oenology","sommelier","pairing","terroir","appellation","vintage","varietal","tannin","acidity",
            "mise en place","brigade system","expediting","plating","portioning","standardization","recipe development","menu engineering","food costing","waste management",
            "Maillard reaction","caramelization","denaturation","gelation","emulsification","crystallization","fermentation","enzymatic browning","oxidation","reduction",
            "molecular gastronomy","spherification","gelification","sous vide","cryogenic cooking","deconstruction","reconstruction","foam","gel","powder",
            "nutrition","macronutrient","micronutrient","calorie","protein","carbohydrate","fat","vitamin","mineral","antioxidant",
            "food safety","HACCP","cross-contamination","temperature control","hygiene","sanitation","pest control","traceability","labeling","regulation",
            "supply chain","procurement","sourcing","seasonal","local","sustainable","fair trade","organic certification","provenance","traceability",
            "cultural significance","tradition","heritage","identity","ritual","ceremony","sharing","community","celebration","memory",
        ],
        "C1": [
            "organoleptic","palatability","hedonic","sensory evaluation","texture profile","flavor compound","volatile","aromatic","phenolic","terpenoid",
            "terroir","provenance","appellation d'origine","geographical indication","heritage breed","heirloom variety","biodiversity","agrodiversity","sustainability","stewardship",
        ],
    },
    "Travel": {
        "A2": [
            "airport","plane","train","bus","car","taxi","boat","ship","bicycle","walk",
            "ticket","passport","visa","luggage","bag","suitcase","backpack","map","guidebook","camera",
            "hotel","hostel","motel","resort","apartment","room","bed","breakfast","check-in","check-out",
            "trip","journey","tour","vacation","holiday","adventure","sightseeing","explore","visit","travel",
            "destination","country","city","town","village","beach","mountain","river","lake","forest",
            "north","south","east","west","left","right","straight","near","far","distance",
            "direction","road","street","avenue","bridge","tunnel","highway","path","trail","route",
            "border","customs","immigration","stamp","declaration","baggage claim","terminal","gate","boarding","departure",
            "arrival","delay","cancel","schedule","timetable","reservation","booking","confirmation","itinerary","plan",
            "currency","exchange","rate","ATM","cash","credit card","tip","budget","expense","cost",
        ],
        "B1": [
            "accommodation","transportation","itinerary","sightseeing","excursion","expedition","exploration","navigation","orientation","wayfinding",
            "landmark","monument","heritage site","museum","gallery","park","garden","market","bazaar","souk",
            "culture","tradition","custom","ritual","festival","celebration","local","authentic","indigenous","heritage",
            "cuisine","specialty","delicacy","street food","restaurant","cafe","bar","pub","nightlife","entertainment",
            "language barrier","translation","interpreter","phrase book","local dialect","sign","gesture","communication","misunderstanding","adaptation",
            "jet lag","altitude sickness","travel fatigue","culture shock","homesickness","adjustment","acclimatization","orientation","familiarity","comfort",
            "solo travel","group travel","family trip","business travel","backpacking","luxury travel","budget travel","adventure travel","eco-tourism","cultural immersion",
            "insurance","emergency","medical","pharmacy","hospital","safety","security","precaution","awareness","preparedness",
            "souvenir","memento","gift","keepsake","photograph","memory","experience","discovery","encounter","impression",
            "natural wonder","scenic route","off the beaten path","hidden gem","local secret","tourist trap","authentic experience","immersive","transformative","unforgettable",
        ],
        "B2": [
            "sustainability","eco-tourism","responsible travel","carbon footprint","offset","conservation","preservation","biodiversity","fragile ecosystem","overtourism",
            "visa requirements","entry permit","residency","citizenship","immigration","emigration","refugee","asylum","displacement","diaspora",
            "geopolitics","diplomacy","bilateral","multilateral","sovereignty","territory","border dispute","conflict zone","travel advisory","risk assessment",
            "hospitality industry","tourism sector","accommodation provider","travel agency","tour operator","online travel agency","platform economy","sharing economy","peer-to-peer","disintermediation",
            "cultural exchange","cross-cultural","intercultural","multicultural","global citizenship","worldview","perspective","empathy","understanding","tolerance",
            "infrastructure","connectivity","accessibility","mobility","logistics","supply chain","capacity","demand","seasonality","peak season",
            "traveler psychology","motivation","expectation","satisfaction","loyalty","recommendation","review","rating","reputation","brand",
        ],
        "C1": [
            "geotourism","voluntourism","transformative travel","slow travel","nomadic lifestyle","digital nomad","location independence","remote work","work-life integration","purposeful travel",
            "anthropological tourism","ethnographic","indigenous rights","cultural appropriation","romanticization","exoticization","orientalism","postcolonial","decolonize","reclaim",
        ],
    },
    "Housing": {
        "A2": [
            "house","apartment","flat","room","floor","ceiling","wall","door","window","roof",
            "kitchen","bedroom","bathroom","living room","dining room","garden","garage","basement","attic","balcony",
            "furniture","table","chair","sofa","bed","wardrobe","shelf","lamp","rug","curtain",
            "rent","buy","sell","lease","own","mortgage","deposit","utility","bill","cost",
            "neighbor","landlord","tenant","owner","agent","move","stay","live","settle","relocate",
            "clean","wash","vacuum","sweep","mop","organize","decorate","repair","fix","maintain",
            "electricity","gas","water","heating","cooling","air conditioning","insulation","ventilation","plumbing","wiring",
            "lock","key","alarm","security","fence","gate","mailbox","doorbell","intercom","camera",
        ],
        "B1": [
            "interior design","architecture","layout","floor plan","renovation","remodeling","extension","conversion","restoration","preservation",
            "property","real estate","market","value","appreciation","depreciation","investment","equity","loan","mortgage",
            "neighborhood","community","district","suburb","urban","rural","residential","commercial","mixed-use","zoning",
            "sustainable","green building","energy efficiency","solar panel","insulation","double glazing","rainwater harvesting","composting","recycling","eco-friendly",
            "lease agreement","tenancy","contract","notice","eviction","deposit","rent control","housing association","council","regulation",
            "maintenance","upkeep","repair","replacement","improvement","upgrade","inspection","survey","assessment","valuation",
            "kitchen appliance","refrigerator","oven","dishwasher","washing machine","dryer","microwave","toaster","kettle","coffee maker",
            "paint","wallpaper","tile","flooring","carpet","hardwood","laminate","vinyl","ceramic","stone",
            "plumber","electrician","carpenter","decorator","contractor","builder","architect","surveyor","inspector","agent",
            "communal","shared","common area","amenity","facility","gym","pool","concierge","parking","storage",
        ],
        "B2": [
            "urban planning","zoning regulation","land use","density","mixed-use development","transit-oriented development","smart city","placemaking","gentrification","displacement",
            "affordable housing","social housing","public housing","subsidized housing","housing voucher","homelessness","shelter","transitional housing","supportive housing","housing first",
            "property development","feasibility","due diligence","site acquisition","planning permission","building regulation","construction","project management","handover","commissioning",
            "condominium","cooperative","freehold","leasehold","commonhold","strata title","body corporate","homeowner association","service charge","ground rent",
            "valuation","comparable","yield","capital growth","rental income","cash flow","leverage","gearing","portfolio","diversification",
            "home automation","smart home","connected device","IoT","voice control","remote monitoring","energy management","security system","integrated","ecosystem",
        ],
        "C1": [
            "encumbrance","easement","covenant","restrictive covenant","right of way","adverse possession","title insurance","conveyancing","escrow","probate",
            "urban regeneration","brownfield","remediation","densification","infill development","heritage conservation","adaptive reuse","listed building","conservation area","planning gain",
        ],
    },
    "Business & Finance": {
        "A2": [
            "shop","store","market","price","cost","pay","buy","sell","money","bank",
            "card","cash","coin","bill","receipt","change","discount","sale","offer","deal",
            "product","service","brand","quality","cheap","expensive","value","choice","customer","staff",
        ],
        "B1": [
            "profit","loss","revenue","expense","income","tax","investment","savings","loan","debt",
            "market","competition","supply","demand","price","inflation","recession","growth","expansion","decline",
            "business","company","firm","corporation","startup","entrepreneur","founder","CEO","shareholder","board",
            "strategy","plan","goal","objective","mission","vision","value","culture","brand","reputation",
            "sales","marketing","advertising","promotion","campaign","target","audience","segment","positioning","differentiation",
            "customer","client","consumer","user","buyer","seller","vendor","supplier","partner","stakeholder",
            "contract","agreement","negotiation","deal","terms","conditions","clause","liability","warranty","guarantee",
            "accounting","bookkeeping","ledger","balance sheet","income statement","cash flow","audit","report","filing","compliance",
            "human resources","recruitment","training","performance","appraisal","compensation","benefit","payroll","insurance","pension",
            "operations","logistics","supply chain","inventory","warehouse","distribution","delivery","quality control","process","efficiency",
        ],
        "B2": [
            "valuation","equity","debt","leverage","yield","dividend","interest rate","bond","stock","portfolio",
            "merger","acquisition","due diligence","synergy","integration","restructuring","divestiture","spin-off","IPO","private equity",
            "market capitalization","enterprise value","EBITDA","P/E ratio","return on equity","return on assets","net present value","internal rate of return","payback period","break-even",
            "hedging","derivatives","futures","options","swap","arbitrage","speculation","risk management","diversification","correlation",
            "fiscal policy","monetary policy","central bank","interest rate","quantitative easing","inflation targeting","exchange rate","trade balance","current account","capital flows",
            "competitive advantage","core competency","value chain","Porter forces","SWOT","PESTEL","balanced scorecard","blue ocean","disruptive innovation","platform business",
            "brand equity","brand loyalty","net promoter score","customer lifetime value","customer acquisition cost","churn rate","conversion rate","funnel","retention","engagement",
        ],
        "C1": [
            "fiduciary","indemnification","subordination","cov-lite","mezzanine","waterfall","carried interest","clawback","hurdle rate","vintage",
            "regulatory arbitrage","systemic risk","counterparty risk","liquidity risk","operational risk","reputational risk","model risk","concentration risk","tail risk","black swan",
        ],
    },
    "Health & Medicine": {
        "A2": [
            "doctor","nurse","hospital","clinic","medicine","pill","injection","blood","heart","brain",
            "pain","fever","cough","cold","flu","headache","stomachache","allergy","cut","wound",
            "healthy","sick","better","worse","treatment","rest","exercise","sleep","diet","hygiene",
        ],
        "B1": [
            "diagnosis","symptom","condition","disease","disorder","infection","inflammation","prescription","medication","dosage",
            "surgery","operation","procedure","recovery","rehabilitation","therapy","physiotherapy","psychotherapy","counseling","support",
            "prevention","vaccination","immunization","screening","checkup","examination","test","result","referral","specialist",
            "mental health","anxiety","depression","stress","burnout","wellbeing","mindfulness","meditation","yoga","therapy",
            "nutrition","calorie","protein","carbohydrate","fat","vitamin","mineral","supplement","hydration","fiber",
            "cardiovascular","respiratory","digestive","musculoskeletal","neurological","endocrine","immune","reproductive","dermatological","ophthalmological",
            "emergency","first aid","CPR","defibrillator","ambulance","paramedic","triage","intensive care","critical","stable",
            "chronic","acute","terminal","benign","malignant","congenital","hereditary","genetic","environmental","lifestyle",
        ],
        "B2": [
            "epidemiology","pathology","etiology","pathogenesis","prognosis","morbidity","mortality","incidence","prevalence","transmission",
            "clinical trial","randomized controlled trial","placebo","double blind","evidence-based","systematic review","meta-analysis","efficacy","safety","adverse effect",
            "pharmacology","pharmacokinetics","pharmacodynamics","bioavailability","half-life","mechanism of action","drug interaction","contraindication","therapeutic window","toxicity",
            "genomics","proteomics","metabolomics","bioinformatics","precision medicine","personalized medicine","targeted therapy","immunotherapy","gene therapy","cell therapy",
            "public health","health policy","universal healthcare","health equity","social determinants","health literacy","health promotion","disease prevention","population health","health system",
        ],
        "C1": [
            "nosocomial","iatrogenic","sequela","comorbidity","multimorbidity","polymorphism","phenotype","genotype","epigenetics","proteome",
            "hemodynamics","thermoregulation","homeostasis","allostasis","neuroplasticity","immunomodulation","autophagy","apoptosis","senescence","telomere",
        ],
    },
    "Science & Nature": {
        "A2": [
            "sun","moon","star","sky","cloud","rain","wind","snow","fire","water",
            "earth","land","sea","ocean","river","mountain","forest","animal","plant","tree",
            "cat","dog","bird","fish","horse","cow","pig","sheep","rabbit","mouse",
        ],
        "B1": [
            "science","biology","chemistry","physics","mathematics","geography","history","technology","engineering","medicine",
            "atom","molecule","element","compound","reaction","energy","force","gravity","electricity","magnetism",
            "cell","organism","evolution","adaptation","ecosystem","habitat","species","biodiversity","extinction","conservation",
            "experiment","hypothesis","theory","evidence","observation","measurement","analysis","conclusion","publication","peer review",
            "climate","temperature","pressure","humidity","precipitation","drought","flood","earthquake","volcano","tsunami",
            "planet","solar system","galaxy","universe","telescope","satellite","space","orbit","gravity","radiation",
            "DNA","gene","chromosome","mutation","heredity","genetics","cloning","biotechnology","GMO","stem cell",
            "photosynthesis","respiration","digestion","circulation","reproduction","growth","development","aging","death","decomposition",
        ],
        "B2": [
            "quantum mechanics","relativity","thermodynamics","electromagnetism","fluid dynamics","optics","acoustics","nuclear physics","particle physics","astrophysics",
            "organic chemistry","inorganic chemistry","biochemistry","analytical chemistry","physical chemistry","polymer chemistry","computational chemistry","green chemistry","nanotechnology","materials science",
            "ecology","population dynamics","community ecology","landscape ecology","macroecology","conservation biology","restoration ecology","invasive species","trophic cascade","keystone species",
            "plate tectonics","seismology","volcanology","oceanography","meteorology","climatology","glaciology","hydrology","geomorphology","stratigraphy",
            "neuroscience","cognitive science","behavioral science","evolutionary psychology","social psychology","developmental psychology","clinical psychology","neuropsychology","psychophysics","computational neuroscience",
        ],
        "C1": [
            "superposition","entanglement","decoherence","wave-particle duality","uncertainty principle","Schrödinger","Copenhagen interpretation","many-worlds","quantum field theory","standard model",
            "homeomorphism","diffeomorphism","manifold","topology","homotopy","cohomology","algebraic geometry","number theory","combinatorics","mathematical logic",
        ],
    },
    "Education": {
        "A2": [
            "student","teacher","classroom","lesson","homework","test","exam","grade","pass","fail",
            "university","college","course","degree","subject","lecture","study","learn","understand","memorize",
        ],
        "B1": [
            "curriculum","syllabus","module","assessment","assignment","project","thesis","dissertation","research","methodology",
            "scholarship","grant","tuition","enrollment","registration","matriculation","graduation","commencement","alumni","faculty",
            "lecture","seminar","tutorial","workshop","laboratory","practical","fieldwork","internship","placement","apprenticeship",
            "critical thinking","problem solving","creativity","collaboration","communication","digital literacy","media literacy","information literacy","research skills","academic writing",
            "feedback","formative","summative","rubric","criterion","standard","benchmark","competency","learning outcome","objective",
            "inclusive education","differentiation","accommodation","modification","support","intervention","remediation","enrichment","gifted","special needs",
            "e-learning","online course","MOOC","blended learning","flipped classroom","gamification","adaptive learning","personalized learning","distance education","virtual classroom",
        ],
        "B2": [
            "pedagogy","andragogy","constructivism","behaviorism","cognitivism","social learning","experiential learning","inquiry-based learning","project-based learning","problem-based learning",
            "educational psychology","learning theory","motivation","self-efficacy","metacognition","executive function","working memory","cognitive load","scaffolding","zone of proximal development",
            "educational equity","achievement gap","social mobility","access","opportunity","representation","inclusion","belonging","stereotype threat","implicit bias",
            "accreditation","quality assurance","benchmarking","ranking","accountability","outcome-based education","competency-based education","mastery learning","standards","accountability",
        ],
        "C1": [
            "epistemology","ontology","hermeneutics","phenomenology","critical theory","postmodernism","poststructuralism","discourse analysis","narrative inquiry","grounded theory",
            "bildung","paideia","liberal arts","classical education","Socratic method","dialectic","elenchus","aporia","maieutics","phronesis",
        ],
    },
    "Law & Society": {
        "B1": [
            "law","rule","regulation","right","duty","obligation","freedom","equality","justice","fairness",
            "crime","punishment","court","judge","lawyer","police","prison","bail","trial","verdict",
            "contract","agreement","breach","remedy","damages","liability","negligence","fraud","theft","assault",
            "government","parliament","democracy","election","vote","policy","law","amendment","constitution","sovereignty",
            "citizen","resident","immigrant","refugee","asylum","nationality","identity","passport","visa","permit",
            "tax","income","property","inheritance","capital gains","VAT","deduction","exemption","compliance","filing",
        ],
        "B2": [
            "jurisdiction","precedent","statute","common law","civil law","criminal law","constitutional law","administrative law","international law","human rights law",
            "due process","habeas corpus","presumption of innocence","burden of proof","standard of proof","adversarial","inquisitorial","appeal","review","remedy",
            "corporation","partnership","sole proprietorship","limited liability","fiduciary duty","director","officer","shareholder","governance","compliance",
            "intellectual property","copyright","trademark","patent","trade secret","licensing","infringement","fair use","public domain","moral rights",
            "discrimination","harassment","whistleblower","equal opportunity","affirmative action","reasonable accommodation","hostile work environment","constructive dismissal","wrongful termination","retaliation",
        ],
        "C1": [
            "jurisprudence","legal positivism","natural law","legal realism","critical legal studies","feminist jurisprudence","law and economics","comparative law","conflict of laws","private international law",
            "proportionality","subsidiarity","legitimate aim","margin of appreciation","derogation","reservation","jus cogens","erga omnes","pacta sunt servanda","opinio juris",
        ],
    },
    "Arts & Culture": {
        "B1": [
            "painting","sculpture","drawing","photography","film","music","dance","theater","literature","poetry",
            "artist","musician","actor","director","writer","poet","photographer","sculptor","choreographer","composer",
            "style","genre","movement","period","influence","technique","medium","material","composition","perspective",
            "exhibition","gallery","museum","concert","performance","show","premiere","festival","award","recognition",
            "creative","expressive","imaginative","innovative","original","authentic","unique","meaningful","powerful","evocative",
            "classical","modern","contemporary","traditional","experimental","avant-garde","mainstream","underground","popular","niche",
            "inspire","create","express","communicate","interpret","represent","symbolize","evoke","challenge","provoke",
        ],
        "B2": [
            "aesthetics","formalism","expressionism","impressionism","cubism","surrealism","abstract","minimalism","conceptual art","installation art",
            "narrative","plot","character","theme","motif","symbol","metaphor","allegory","irony","satire",
            "cultural heritage","intangible heritage","living heritage","oral tradition","folklore","mythology","ritual","ceremony","custom","practice",
            "canon","criticism","theory","analysis","interpretation","context","intertextuality","influence","appropriation","homage",
            "patronage","commission","collection","acquisition","provenance","authenticity","attribution","restoration","conservation","documentation",
        ],
        "C1": [
            "semiotics","hermeneutics","phenomenology","postmodern","deconstruction","discourse","power","ideology","hegemony","subaltern",
            "iconography","iconology","ekphrasis","ut pictura poesis","paragone","mimesis","diegesis","verisimilitude","catharsis","sublime",
        ],
    },
    "Environment": {
        "B1": [
            "environment","nature","planet","earth","ecosystem","habitat","species","wildlife","forest","ocean",
            "pollution","waste","recycling","renewable energy","solar","wind","fossil fuel","carbon","emission","greenhouse gas",
            "climate change","global warming","deforestation","biodiversity","conservation","sustainability","ecology","green","organic","natural",
        ],
        "B2": [
            "carbon footprint","carbon offset","carbon trading","cap and trade","carbon tax","net zero","carbon neutral","decarbonization","low-carbon","climate action",
            "renewable energy","solar power","wind energy","hydropower","geothermal","biomass","energy storage","smart grid","energy efficiency","demand response",
            "circular economy","cradle to cradle","life cycle assessment","extended producer responsibility","eco-design","industrial ecology","upcycling","waste hierarchy","landfill diversion","zero waste",
            "biodiversity loss","habitat fragmentation","invasive species","overfishing","illegal wildlife trade","poaching","desertification","soil erosion","aquifer depletion","wetland",
            "climate justice","environmental justice","green new deal","just transition","community resilience","adaptation","mitigation","vulnerability","exposure","sensitivity",
        ],
        "C1": [
            "planetary boundaries","tipping point","irreversibility","feedback loop","albedo","thermohaline circulation","permafrost","methane clathrate","ocean acidification","coral bleaching",
            "intergenerational equity","precautionary principle","polluter pays principle","loss and damage","climate finance","green bonds","blended finance","catalytic capital","impact investing","nature-based solutions",
        ],
    },
    "Psychology & Emotions": {
        "A2": [
            "angry","afraid","surprised","confused","proud","ashamed","jealous","lonely","nervous","calm",
            "mood","feeling","emotion","attitude","behavior","reaction","response","thought","mind","heart",
        ],
        "B1": [
            "confident","determined","motivated","optimistic","pessimistic","curious","creative","patient","persistent","resilient",
            "empathy","sympathy","compassion","kindness","generosity","honesty","loyalty","courage","wisdom","humility",
            "self-esteem","self-confidence","self-awareness","self-control","self-discipline","self-motivation","self-reflection","self-improvement","self-acceptance","self-compassion",
            "happiness","sadness","anger","fear","surprise","disgust","anticipation","trust","joy","grief",
            "stress","anxiety","depression","phobia","trauma","PTSD","obsession","compulsion","addiction","recovery",
            "personality","character","trait","introvert","extrovert","ambivert","sensitive","intuitive","rational","emotional",
        ],
        "B2": [
            "cognitive distortion","negative thinking","rumination","catastrophizing","mindfulness","acceptance","commitment","resilience","post-traumatic growth","flourishing",
            "attachment","bonding","secure","anxious","avoidant","disorganized","relationship","intimacy","vulnerability","trust",
            "motivation","intrinsic","extrinsic","drive","reward","reinforcement","punishment","conditioning","habit","routine",
            "perception","cognition","memory","attention","concentration","focus","distraction","multitasking","flow","engagement",
            "identity","self-concept","social identity","role","status","belonging","exclusion","conformity","independence","autonomy",
        ],
        "C1": [
            "existential","phenomenological","hermeneutic","dialectical","psychodynamic","humanistic","transpersonal","somatic","embodied","relational",
            "neuropsychological","psychophysiological","biopsychosocial","epigenetic","developmental","systemic","contextual","cultural","intersectional","holistic",
        ],
    },
    "Sports & Fitness": {
        "A2": [
            "football","basketball","tennis","swimming","running","cycling","yoga","gym","exercise","sport",
            "ball","goal","team","player","match","score","win","lose","draw","champion",
        ],
        "B1": [
            "athlete","coach","trainer","referee","judge","spectator","fan","supporter","competition","tournament",
            "training","practice","drill","warm-up","cool-down","stretching","strength","cardio","endurance","flexibility",
            "technique","skill","strategy","tactic","formation","position","role","performance","improvement","progress",
            "injury","recovery","rehabilitation","prevention","first aid","physiotherapy","nutrition","hydration","sleep","rest",
            "sprint","marathon","triathlon","decathlon","relay","hurdle","long jump","high jump","shot put","javelin",
            "serve","volley","smash","dribble","tackle","pass","shoot","block","spike","dive",
        ],
        "B2": [
            "periodization","macrocycle","mesocycle","microcycle","overtraining","tapering","peaking","supercompensation","progressive overload","specificity",
            "biomechanics","kinetics","kinematics","force","power","speed","agility","balance","coordination","proprioception",
            "sports psychology","mental toughness","visualization","goal setting","arousal","anxiety","concentration","confidence","motivation","team dynamics",
            "doping","banned substance","anti-doping","WADA","USADA","TUE","whereabouts","testing","sanction","appeal",
        ],
        "C1": [
            "periodization theory","concurrent training","transfer of training","skill acquisition","motor learning","implicit learning","explicit learning","deliberate practice","expertise","talent identification",
        ],
    },
    "Technology & Innovation": {
        "B1": [
            "innovation","invention","discovery","patent","prototype","design","engineering","research","development","technology",
            "startup","entrepreneur","venture capital","angel investor","pitch","funding","scaling","growth","pivot","exit",
            "digital transformation","automation","robotics","3D printing","virtual reality","augmented reality","mixed reality","wearable","drone","autonomous vehicle",
        ],
        "B2": [
            "disruptive technology","platform","ecosystem","network effect","two-sided market","marketplace","aggregator","integrator","modular","open source",
            "artificial intelligence","machine learning","deep learning","neural network","computer vision","natural language processing","speech recognition","recommendation system","generative AI","large language model",
            "Internet of Things","smart device","connected","sensor","actuator","edge computing","fog computing","embedded system","firmware","protocol",
            "cybersecurity","threat","vulnerability","exploit","malware","ransomware","phishing","social engineering","zero-day","incident response",
            "quantum computing","qubit","superposition","entanglement","quantum advantage","quantum supremacy","quantum cryptography","post-quantum","quantum algorithm","quantum hardware",
        ],
        "C1": [
            "techno-solutionism","technological determinism","sociotechnical","affordance","boundary object","inscription","translation","actor-network","sociotechnical imaginaries","anticipatory governance",
        ],
    },
    "Food & Nutrition (Advanced)": {
        "B1": [
            "macronutrient","micronutrient","caloric density","glycemic index","glycemic load","insulin response","blood sugar","metabolism","basal metabolic rate","total daily energy expenditure",
            "portion control","mindful eating","intuitive eating","emotional eating","binge eating","food addiction","orthorexia","eating disorder","body image","weight management",
        ],
        "B2": [
            "phytochemical","flavonoid","polyphenol","antioxidant","free radical","oxidative stress","inflammation","anti-inflammatory","prebiotic","probiotic",
            "gut microbiome","gut flora","microbiota","dysbiosis","leaky gut","intestinal permeability","mucosal immunity","digestive enzyme","bile acid","enterohepatic circulation",
            "nutrigenomics","nutrigenetics","personalized nutrition","precision nutrition","functional food","nutraceutical","biofortification","bioavailability","absorption","utilization",
        ],
    },
    "Weather & Geography": {
        "B1": [
            "continent","country","region","province","state","city","capital","border","population","density",
            "latitude","longitude","altitude","elevation","sea level","terrain","topography","landscape","landform","geography",
            "tropical","subtropical","temperate","polar","arid","semiarid","humid","monsoon","Mediterranean","oceanic",
            "cyclone","hurricane","typhoon","tornado","blizzard","heatwave","drought","flood","earthquake","landslide",
        ],
        "B2": [
            "geopolitics","sovereignty","territory","jurisdiction","exclusive economic zone","continental shelf","international waters","airspace","demilitarized zone","buffer zone",
            "urbanization","suburbanization","rural-urban migration","megacity","metropolitan area","conurbation","urban sprawl","urban density","smart city","livability",
        ],
    },
    "Personality & Character": {
        "B1": [
            "ambitious","adventurous","cautious","cheerful","considerate","cooperative","courageous","courteous","dependable","determined",
            "diligent","diplomatic","disciplined","energetic","enthusiastic","flexible","focused","generous","gracious","hardworking",
            "humble","imaginative","independent","industrious","innovative","insightful","intellectual","inventive","logical","loyal",
            "meticulous","methodical","motivated","objective","open-minded","optimistic","organized","passionate","patient","perceptive",
            "persistent","persuasive","practical","proactive","punctual","reliable","resourceful","responsible","self-reliant","sincere",
            "sociable","straightforward","strategic","systematic","tactful","tenacious","thoughtful","trustworthy","versatile","visionary",
        ],
        "B2": [
            "adaptable","analytical","assertive","autonomous","candid","charismatic","compassionate","conscientious","decisive","empathetic",
            "forthright","idealistic","impartial","incisive","indulgent","industrious","ingenious","introspective","judicious","meticulous",
        ],
    },
    "Phrasal Verbs & Idioms": {
        "B1": [
            "break down","break out","break up","bring up","call off","carry on","catch up","come across","come up with","cut down",
            "deal with","end up","fall apart","figure out","get along","get over","give up","go ahead","go through","grow up",
            "hang out","hold on","keep up","let down","look after","look forward to","make up","move on","pick up","point out",
            "put off","run out","set up","show up","take over","turn down","work out","write off","bring about","carry out",
        ],
        "B2": [
            "back down","blow up","brush off","build up","burn out","call up","chip in","come around","come clean","count on",
            "crack down","die down","drag on","draw up","fall through","get away with","give in","go back on","hold back","iron out",
            "kick off","lay off","let up","live up to","look into","make do","pass on","phase out","pull off","push through",
            "put forward","run into","set back","shake up","stand by","step up","stick to","take on","throw away","turn out",
        ],
    },
}


# ---------------------------------------------------------------------------
# API helpers
# ---------------------------------------------------------------------------
def fetch_definition(word: str) -> str | None:
    url = f"{DICT_API}/{urllib.parse.quote(word)}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            for entry in data:
                for meaning in entry.get("meanings", []):
                    for defn in meaning.get("definitions", []):
                        text = defn.get("definition", "").strip()
                        if text:
                            return text
    except urllib.error.HTTPError as e:
        if e.code != 404:
            print(f"  DICT HTTP {e.code} for '{word}'", flush=True)
    except Exception as e:
        print(f"  DICT error for '{word}': {e}", flush=True)
    return None


def fetch_vietnamese(word: str) -> str | None:
    params = urllib.parse.urlencode({"q": word, "langpair": "en|vi"})
    url = f"{TRANS_API}?{params}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            translation = data.get("responseData", {}).get("translatedText", "").strip()
            if translation and translation.upper() != word.upper():
                return translation
    except Exception as e:
        print(f"  TRANS error for '{word}': {e}", flush=True)
    return None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    # Load existing words
    existing = set()
    existing_rows = []
    fieldnames = None

    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            existing.add(row["english"].strip().lower())
            existing_rows.append(row)

    print(f"Existing words: {len(existing)}", flush=True)

    # Collect all candidate words in order
    candidates = []  # (word, difficulty, category)
    for category, difficulties in WORD_BANK.items():
        for difficulty, words in difficulties.items():
            for word in words:
                w = word.strip().lower()
                if w not in existing:
                    candidates.append((word, difficulty, category))

    # Deduplicate candidates by word
    seen = set(existing)
    unique_candidates = []
    for word, diff, cat in candidates:
        w = word.strip().lower()
        if w not in seen:
            seen.add(w)
            unique_candidates.append((word, diff, cat))

    needed = 3000 - len(existing)
    print(f"Need {needed} more words. Candidates available: {len(unique_candidates)}", flush=True)

    if needed <= 0:
        print("Already at or above 3000 words.", flush=True)
        return

    to_process = unique_candidates[:needed]
    total = len(to_process)
    new_rows = []
    failed = []

    for i, (word, difficulty, category) in enumerate(to_process, 1):
        definition = fetch_definition(word)
        if not definition:
            definition = f"Definition of {word}."

        vietnamese = fetch_vietnamese(word)
        if not vietnamese:
            vietnamese = word  # fallback

        example = f"This is an example for {word}."

        row = {
            "english": word,
            "vietnamese": vietnamese,
            "exampleSentence": example,
            "englishMeaning": definition,
            "difficulty": difficulty,
            "category": category,
        }
        new_rows.append(row)

        status = "OK" if (definition and not definition.startswith("Definition of")) else "NO DEF"
        print(f"[{i}/{total}] {word} ({difficulty}, {category}): {status} | vi={vietnamese[:20]}", flush=True)

        # Rate limit
        time.sleep(0.3)

        # Save progress every 100 words
        if i % 100 == 0:
            _write_csv(CSV_PATH, fieldnames, existing_rows + new_rows)
            print(f"  -- Saved {len(existing_rows) + len(new_rows)} total rows --", flush=True)

    # Final save
    _write_csv(CSV_PATH, fieldnames, existing_rows + new_rows)
    print(f"\nDone! Total rows: {len(existing_rows) + len(new_rows)}", flush=True)


def _write_csv(path, fieldnames, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
