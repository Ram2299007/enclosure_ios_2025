import SwiftUI
import PhotosUI

// MARK: - Lookup tables (mirrors Android PostAdvertiseActivity)

private let kCountries: [String] = [
    "Afghanistan","Albania","Algeria","Argentina","Australia","Austria",
    "Bangladesh","Belgium","Brazil","Canada","China","Colombia","Croatia",
    "Denmark","Egypt","Ethiopia","Finland","France","Germany","Ghana",
    "Greece","India","Indonesia","Iran","Iraq","Ireland","Israel","Italy",
    "Japan","Jordan","Kenya","Malaysia","Mexico","Morocco","Netherlands",
    "New Zealand","Nigeria","Norway","Pakistan","Philippines","Poland",
    "Portugal","Romania","Russia","Saudi Arabia","South Africa","South Korea",
    "Spain","Sri Lanka","Sweden","Switzerland","Tanzania","Thailand","Turkey",
    "Uganda","Ukraine","United Arab Emirates","United Kingdom","United States",
    "Vietnam","Zimbabwe"
]

private let kCategories: [String] = [
    "Select Category","Technology","Fashion & Beauty","Food & Beverage",
    "Health & Fitness","Travel & Tourism","Education","Entertainment",
    "Real Estate","Automotive","Finance & Banking","Sports","Music",
    "Art & Design","Business & Marketing","Jobs & Careers","Events",
    "Shopping & Retail","Home & Garden","Pets & Animals","Other"
]

private let kDialToCountry: [String: String] = [
    "+93":"Afghanistan","+355":"Albania","+213":"Algeria","+54":"Argentina",
    "+61":"Australia","+43":"Austria","+880":"Bangladesh","+32":"Belgium",
    "+55":"Brazil","+1":"United States","+86":"China","+57":"Colombia",
    "+385":"Croatia","+45":"Denmark","+20":"Egypt","+251":"Ethiopia",
    "+358":"Finland","+33":"France","+49":"Germany","+233":"Ghana",
    "+30":"Greece","+91":"India","+62":"Indonesia","+98":"Iran",
    "+964":"Iraq","+353":"Ireland","+972":"Israel","+39":"Italy",
    "+81":"Japan","+962":"Jordan","+254":"Kenya","+60":"Malaysia",
    "+52":"Mexico","+212":"Morocco","+31":"Netherlands","+64":"New Zealand",
    "+234":"Nigeria","+47":"Norway","+92":"Pakistan","+63":"Philippines",
    "+48":"Poland","+351":"Portugal","+40":"Romania","+7":"Russia",
    "+966":"Saudi Arabia","+27":"South Africa","+82":"South Korea",
    "+34":"Spain","+94":"Sri Lanka","+46":"Sweden","+41":"Switzerland",
    "+255":"Tanzania","+66":"Thailand","+90":"Turkey","+256":"Uganda",
    "+380":"Ukraine","+971":"United Arab Emirates","+44":"United Kingdom",
    "+84":"Vietnam","+263":"Zimbabwe"
]

private let kCountryCurrency: [String: String] = [
    "India":"₹","Nepal":"₹","Bhutan":"₹",
    "United States":"$","Zimbabwe":"$","El Salvador":"$",
    "United Kingdom":"£",
    "Germany":"€","France":"€","Italy":"€","Spain":"€","Portugal":"€",
    "Netherlands":"€","Belgium":"€","Austria":"€","Finland":"€",
    "Greece":"€","Croatia":"€","Ireland":"€",
    "Australia":"A$","Canada":"C$",
    "United Arab Emirates":"د.إ","Saudi Arabia":"﷼","Iran":"﷼",
    "Brazil":"R$","China":"¥","Japan":"¥","South Korea":"₩",
    "Pakistan":"₨","Bangladesh":"৳","Malaysia":"RM","Philippines":"₱",
    "Thailand":"฿","Turkey":"₺","South Africa":"R","Nigeria":"₦",
    "Indonesia":"Rp","Vietnam":"₫","Ukraine":"₴","Russia":"₽",
    "Mexico":"MX$","Argentina":"AR$","Egypt":"E£","Iraq":"IQD",
    "Poland":"zł","Denmark":"kr","Sweden":"kr","Norway":"kr",
    "Switzerland":"CHF","New Zealand":"NZ$","Israel":"₪","Jordan":"JD",
    "Sri Lanka":"රු","Kenya":"KSh","Ethiopia":"Br","Uganda":"USh",
    "Tanzania":"TSh","Ghana":"GH₵","Morocco":"MAD","Algeria":"DA",
    "Afghanistan":"Af","Albania":"L","Colombia":"COP"
]

private let kCurrencyTiers: [String: [Int]] = [
    "₹":[250,500,1000,2000],"$":[3,6,12,25],"£":[3,6,12,25],
    "€":[3,6,12,25],"A$":[5,10,20,40],"C$":[4,8,16,32],
    "د.إ":[11,22,45,90],"﷼":[11,22,45,90],"R$":[15,30,60,120],
    "¥":[450,900,1800,3600],"₩":[4000,8000,16000,32000],
    "₨":[850,1700,3400,6800],"৳":[270,540,1080,2160],
    "RM":[13,26,52,104],"₱":[170,340,680,1360],"฿":[105,210,420,840],
    "₺":[865,1730,3460,6920],"R":[55,110,220,440],"₦":[4000,8000,16000,32000],
    "Rp":[50000,100000,200000,400000],"₫":[62000,124000,248000,500000],
    "₴":[125,250,500,1000],"₽":[275,550,1100,2200],"MX$":[50,100,200,400],
    "AR$":[3400,6800,13600,27200],"E£":[150,300,600,1200],
    "IQD":[4000,8000,16000,32000],"zł":[12,24,48,96],
    "kr":[33,66,132,264],"CHF":[3,6,12,25],"NZ$":[5,10,20,40],
    "₪":[11,22,45,90],"JD":[2,4,8,16],"රු":[900,1800,3600,7200],
    "KSh":[390,780,1560,3120],"Br":[58,116,232,464],
    "USh":[11000,22000,44000,88000],"TSh":[8000,16000,32000,64000],
    "GH₵":[39,78,156,312],"MAD":[30,60,120,240],"DA":[400,800,1600,3200],
    "Af":[218,436,872,1744],"L":[273,546,1092,2184],"COP":[12000,24000,48000,96000]
]

private let kCountryStates: [String: [String]] = [
    "India": [
        "Andhra Pradesh","Arunachal Pradesh","Assam","Bihar","Chhattisgarh","Goa",
        "Gujarat","Haryana","Himachal Pradesh","Jharkhand","Karnataka","Kerala",
        "Madhya Pradesh","Maharashtra","Manipur","Meghalaya","Mizoram","Nagaland",
        "Odisha","Punjab","Rajasthan","Sikkim","Tamil Nadu","Telangana","Tripura",
        "Uttar Pradesh","Uttarakhand","West Bengal","Andaman & Nicobar Islands",
        "Chandigarh","Dadra & Nagar Haveli","Daman & Diu","Delhi",
        "Jammu & Kashmir","Ladakh","Lakshadweep","Puducherry"],
    "United States": [
        "Alabama","Alaska","Arizona","Arkansas","California","Colorado","Connecticut",
        "Delaware","Florida","Georgia","Hawaii","Idaho","Illinois","Indiana","Iowa",
        "Kansas","Kentucky","Louisiana","Maine","Maryland","Massachusetts","Michigan",
        "Minnesota","Mississippi","Missouri","Montana","Nebraska","Nevada",
        "New Hampshire","New Jersey","New Mexico","New York","North Carolina",
        "North Dakota","Ohio","Oklahoma","Oregon","Pennsylvania","Rhode Island",
        "South Carolina","South Dakota","Tennessee","Texas","Utah","Vermont",
        "Virginia","Washington","West Virginia","Wisconsin","Wyoming","Washington D.C."],
    "United Kingdom": [
        "England","Scotland","Wales","Northern Ireland","London","Manchester",
        "Birmingham","Leeds","Glasgow","Liverpool","Bristol","Sheffield","Edinburgh","Cardiff"],
    "Canada": [
        "Alberta","British Columbia","Manitoba","New Brunswick",
        "Newfoundland and Labrador","Northwest Territories","Nova Scotia",
        "Nunavut","Ontario","Prince Edward Island","Quebec","Saskatchewan","Yukon"],
    "Australia": [
        "Australian Capital Territory","New South Wales","Northern Territory",
        "Queensland","South Australia","Tasmania","Victoria","Western Australia"],
    "Germany": [
        "Baden-Württemberg","Bavaria","Berlin","Brandenburg","Bremen","Hamburg",
        "Hesse","Lower Saxony","Mecklenburg-Vorpommern","North Rhine-Westphalia",
        "Rhineland-Palatinate","Saarland","Saxony","Saxony-Anhalt",
        "Schleswig-Holstein","Thuringia"],
    "Brazil": [
        "Acre","Alagoas","Amapá","Amazonas","Bahia","Ceará","Distrito Federal",
        "Espírito Santo","Goiás","Maranhão","Mato Grosso","Mato Grosso do Sul",
        "Minas Gerais","Pará","Paraíba","Paraná","Pernambuco","Piauí",
        "Rio de Janeiro","Rio Grande do Norte","Rio Grande do Sul","Rondônia",
        "Roraima","Santa Catarina","São Paulo","Sergipe","Tocantins"],
    "Pakistan": [
        "Balochistan","Khyber Pakhtunkhwa","Punjab","Sindh",
        "Azad Kashmir","Gilgit-Baltistan","Islamabad Capital Territory"],
    "Bangladesh": ["Barisal","Chittagong","Dhaka","Khulna","Mymensingh","Rajshahi","Rangpur","Sylhet"],
    "Nigeria": [
        "Abia","Adamawa","Akwa Ibom","Anambra","Bauchi","Bayelsa","Benue","Borno",
        "Cross River","Delta","Ebonyi","Edo","Ekiti","Enugu","FCT Abuja","Gombe",
        "Imo","Jigawa","Kaduna","Kano","Katsina","Kebbi","Kogi","Kwara","Lagos",
        "Nasarawa","Niger","Ogun","Ondo","Osun","Oyo","Plateau","Rivers","Sokoto",
        "Taraba","Yobe","Zamfara"],
    "South Africa": [
        "Eastern Cape","Free State","Gauteng","KwaZulu-Natal","Limpopo",
        "Mpumalanga","Northern Cape","North West","Western Cape"],
    "Indonesia": [
        "Aceh","Bali","Bangka Belitung Islands","Banten","Bengkulu","Central Java",
        "Central Kalimantan","Central Sulawesi","East Java","East Kalimantan",
        "East Nusa Tenggara","Gorontalo","Jakarta","Jambi","Lampung","Maluku",
        "North Kalimantan","North Maluku","North Sulawesi","North Sumatra",
        "Papua","Riau","Riau Islands","South Kalimantan","South Sulawesi",
        "South Sumatra","Southeast Sulawesi","West Java","West Kalimantan",
        "West Nusa Tenggara","West Papua","West Sulawesi","West Sumatra","Yogyakarta"],
    "France": [
        "Auvergne-Rhône-Alpes","Bourgogne-Franche-Comté","Bretagne",
        "Centre-Val de Loire","Corse","Grand Est","Hauts-de-France",
        "Île-de-France","Normandie","Nouvelle-Aquitaine","Occitanie",
        "Pays de la Loire","Provence-Alpes-Côte d'Azur"],
    "China": [
        "Anhui","Beijing","Chongqing","Fujian","Gansu","Guangdong","Guangxi",
        "Guizhou","Hainan","Hebei","Heilongjiang","Henan","Hong Kong","Hubei",
        "Hunan","Inner Mongolia","Jiangsu","Jiangxi","Jilin","Liaoning","Macau",
        "Ningxia","Qinghai","Shaanxi","Shandong","Shanghai","Shanxi","Sichuan",
        "Tianjin","Tibet","Xinjiang","Yunnan","Zhejiang"],
    "Malaysia": [
        "Johor","Kedah","Kelantan","Kuala Lumpur","Labuan","Malacca","Negeri Sembilan",
        "Pahang","Penang","Perak","Perlis","Putrajaya","Sabah","Sarawak","Selangor","Terengganu"],
    "Saudi Arabia": [
        "Al-Bahah","Al-Jawf","Al-Madinah","Al-Qassim","Asir","Eastern Province",
        "Ha'il","Jazan","Mecca","Najran","Northern Borders","Riyadh","Tabuk"],
    "United Arab Emirates": [
        "Abu Dhabi","Ajman","Dubai","Fujairah","Ras Al Khaimah","Sharjah","Umm Al Quwain"],
    "Sri Lanka": ["Central","Eastern","North Central","Northern","North Western","Sabaragamuwa","Southern","Uva","Western"],
    "Turkey": [
        "Adana","Ankara","Antalya","Bursa","Diyarbakır","Edirne","Erzurum",
        "Eskişehir","Gaziantep","Istanbul","İzmir","Kahramanmaraş","Kayseri",
        "Konya","Mersin","Samsun","Şanlıurfa","Trabzon"],
    "Russia": [
        "Moscow","Saint Petersburg","Novosibirsk Oblast","Sverdlovsk Oblast",
        "Krasnoyarsk Krai","Nizhny Novgorod Oblast","Tatarstan","Chelyabinsk Oblast",
        "Krasnodar Krai","Rostov Oblast","Bashkortostan","Tyumen Oblast"],
    "Japan": [
        "Aichi","Akita","Aomori","Chiba","Ehime","Fukuoka","Hokkaido","Hyogo",
        "Ibaraki","Kanagawa","Kyoto","Mie","Miyagi","Nagano","Nagasaki","Nara",
        "Niigata","Osaka","Okinawa","Saitama","Shizuoka","Tochigi","Tokyo","Yamaguchi"],
    "South Korea": [
        "Busan","Daegu","Daejeon","Gangwon-do","Gwangju","Gyeonggi-do",
        "Gyeongsangbuk-do","Gyeongsangnam-do","Incheon","Jeju","Jeollabuk-do",
        "Jeollanam-do","Sejong","Seoul","Ulsan"],
    "Mexico": [
        "Aguascalientes","Baja California","Chiapas","Chihuahua","Coahuila",
        "Guanajuato","Jalisco","Mexico City","Mexico State","Michoacan","Morelos",
        "Nuevo Leon","Oaxaca","Puebla","Queretaro","Quintana Roo","Sinaloa",
        "Sonora","Tabasco","Tamaulipas","Veracruz","Yucatan","Zacatecas"],
    "Egypt": [
        "Alexandria","Aswan","Asyut","Cairo","Dakahlia","Faiyum","Gharbia",
        "Giza","Luxor","Minya","Monufia","Port Said","Qalyubia","Qena","Suez"],
    "Kenya": [
        "Baringo","Bomet","Bungoma","Embu","Garissa","Homa Bay","Kajiado","Kakamega",
        "Kiambu","Kilifi","Kisii","Kisumu","Kitui","Machakos","Meru","Mombasa",
        "Nairobi","Nakuru","Nandi","Narok","Nyeri","Siaya","Taita-Taveta",
        "Trans Nzoia","Turkana","Uasin Gishu","Wajir","West Pokot"],
    "Ghana": [
        "Ahafo","Ashanti","Bono","Bono East","Central","Eastern","Greater Accra",
        "North East","Northern","Oti","Savannah","Upper East","Upper West","Volta","Western","Western North"],
    "Ethiopia": [
        "Afar","Amhara","Benishangul-Gumuz","Central Ethiopia","Gambela","Harari",
        "Oromia","Sidama","Somali","South Ethiopia","SNNPR","Tigray","Addis Ababa","Dire Dawa"],
    "Uganda": [
        "Kampala","Gulu","Lira","Mbale","Mbarara","Masaka","Jinja","Arua",
        "Fort Portal","Kasese","Kabale","Moroto","Soroti","Hoima"],
    "Tanzania": [
        "Arusha","Dar es Salaam","Dodoma","Geita","Iringa","Kagera","Katavi",
        "Kigoma","Kilimanjaro","Lindi","Manyara","Mara","Mbeya","Morogoro",
        "Mtwara","Mwanza","Njombe","Pwani","Rukwa","Ruvuma","Shinyanga","Singida","Tabora","Tanga"],
    "Algeria": [
        "Algiers","Oran","Constantine","Annaba","Batna","Setif","Blida","Tlemcen",
        "Bejaia","Skikda","Biskra","Boumerdes","Tipaza","Tizi Ouzou","Djelfa"],
    "Morocco": [
        "Casablanca-Settat","Fes-Meknes","Marrakesh-Safi","Oriental",
        "Rabat-Sale-Kenitra","Souss-Massa","Tanger-Tetouan-Al Hoceima",
        "Beni Mellal-Khenifra","Draa-Tafilalet","Guelmim-Oued Noun","Laayoune-Sakia El Hamra"],
    "Argentina": [
        "Buenos Aires","Buenos Aires City","Catamarca","Chaco","Chubut","Cordoba",
        "Corrientes","Entre Rios","Formosa","Jujuy","La Pampa","La Rioja","Mendoza",
        "Misiones","Neuquen","Rio Negro","Salta","San Juan","San Luis","Santa Cruz",
        "Santa Fe","Santiago del Estero","Tierra del Fuego","Tucuman"],
    "Colombia": [
        "Antioquia","Atlantico","Bogota D.C.","Bolivar","Boyaca","Caldas","Cauca",
        "Cesar","Choco","Cordoba","Cundinamarca","Huila","La Guajira","Magdalena",
        "Meta","Narino","Norte de Santander","Risaralda","Santander","Sucre",
        "Tolima","Valle del Cauca"],
    "Poland": [
        "Greater Poland","Kuyavian-Pomeranian","Lesser Poland","Lodz",
        "Lower Silesian","Lublin","Lubusz","Masovian","Opole","Podlaskie",
        "Pomeranian","Silesian","Subcarpathian","Swietokrzyskie","Warmian-Masurian","West Pomeranian"],
    "Romania": [
        "Arad","Arges","Bacau","Bihor","Bistrita-Nasaud","Botosani","Braila","Brasov",
        "Bucharest","Buzau","Cluj","Constanta","Dolj","Galati","Iasi","Ilfov",
        "Maramures","Mures","Neamt","Prahova","Sibiu","Suceava","Timis","Vrancea"],
    "Ukraine": [
        "Cherkasy","Chernihiv","Chernivtsi","Dnipropetrovsk","Donetsk","Ivano-Frankivsk",
        "Kharkiv","Kherson","Khmelnytskyi","Kiev","Kirovohrad","Luhansk","Lviv",
        "Mykolaiv","Odessa","Poltava","Rivne","Sumy","Ternopil","Vinnytsia",
        "Volyn","Zakarpattia","Zaporizhzhia","Zhytomyr"],
    "Vietnam": [
        "An Giang","Ba Ria-Vung Tau","Bac Giang","Binh Dinh","Binh Duong","Ca Mau",
        "Can Tho","Da Nang","Dak Lak","Dong Nai","Gia Lai","Ha Noi","Ha Tinh",
        "Hai Phong","Ho Chi Minh City","Khanh Hoa","Kien Giang","Lam Dong",
        "Long An","Nam Dinh","Nghe An","Ninh Binh","Quang Nam","Quang Ngai",
        "Quang Ninh","Son La","Thai Nguyen","Thanh Hoa","Thua Thien Hue","Yen Bai"],
    "Sweden": [
        "Blekinge","Dalarna","Gavleborg","Gotland","Halland","Jamtland","Jonkoping",
        "Kalmar","Kronoberg","Norrbotten","Orebro","Ostergotland","Skane",
        "Sodermanland","Stockholm","Uppsala","Varmland","Vasterbotten","Vasternorrland","Vastmanland","Vastra Gotaland"],
    "Netherlands": [
        "Drenthe","Flevoland","Friesland","Gelderland","Groningen","Limburg",
        "North Brabant","North Holland","Overijssel","South Holland","Utrecht","Zeeland"],
    "Belgium": [
        "Antwerp","Brussels-Capital","East Flanders","Flemish Brabant","Hainaut",
        "Liege","Limburg","Luxembourg","Namur","Walloon Brabant","West Flanders"],
    "Switzerland": [
        "Aargau","Basel-Landschaft","Basel-Stadt","Bern","Fribourg","Geneva",
        "Graubunden","Jura","Lucerne","Neuchatel","Nidwalden","Obwalden",
        "Schaffhausen","Schwyz","Solothurn","St. Gallen","Thurgau","Ticino",
        "Uri","Valais","Vaud","Zug","Zurich"],
    "Spain": [
        "Andalusia","Aragon","Asturias","Balearic Islands","Basque Country",
        "Canary Islands","Cantabria","Castile and Leon","Castile-La Mancha",
        "Catalonia","Extremadura","Galicia","La Rioja","Madrid","Murcia","Navarre","Valencia"],
    "Italy": [
        "Abruzzo","Aosta Valley","Apulia","Basilicata","Calabria","Campania",
        "Emilia-Romagna","Friuli-Venezia Giulia","Lazio","Liguria","Lombardy",
        "Marche","Molise","Piedmont","Sardinia","Sicily","Trentino-South Tyrol",
        "Tuscany","Umbria","Veneto"],
    "Portugal": [
        "Aveiro","Beja","Braga","Braganca","Castelo Branco","Coimbra","Evora",
        "Faro","Guarda","Leiria","Lisbon","Portalegre","Porto","Santarem",
        "Setubal","Viana do Castelo","Vila Real","Viseu","Azores","Madeira"],
    "Greece": [
        "Attica","Central Greece","Central Macedonia","Crete","Eastern Macedonia and Thrace",
        "Epirus","Ionian Islands","North Aegean","Peloponnese","South Aegean",
        "Thessaly","Western Greece","Western Macedonia"],
    "Philippines": [
        "Abra","Agusan del Norte","Aklan","Albay","Antique","Aurora","Basilan",
        "Bataan","Batangas","Benguet","Bohol","Bukidnon","Bulacan","Cagayan",
        "Camarines Sur","Cavite","Cebu","Davao del Norte","Davao del Sur",
        "Ilocos Norte","Ilocos Sur","Iloilo","Isabela","La Union","Laguna",
        "Lanao del Norte","Leyte","Metro Manila","Misamis Occidental","Misamis Oriental",
        "Negros Occidental","Negros Oriental","Nueva Ecija","Pampanga","Pangasinan",
        "Quezon","Rizal","Samar","South Cotabato","Sorsogon","Surigao del Norte",
        "Tarlac","Zambales","Zamboanga del Norte","Zamboanga del Sur"],
    "New Zealand": [
        "Auckland","Bay of Plenty","Canterbury","Gisborne","Hawke's Bay",
        "Manawatu-Whanganui","Marlborough","Nelson","Northland","Otago",
        "Southland","Taranaki","Tasman","Waikato","Wellington","West Coast"],
    "Jordan": ["Ajloun","Aqaba","Balqa","Irbid","Jarash","Karak","Ma'an","Madaba","Mafraq","Amman","Tafilah","Zarqa"],
    "Israel": ["Center District","Haifa District","Jerusalem District","Judea and Samaria","Northern District","Southern District","Tel Aviv District"],
    "Iraq": ["Al Anbar","Al Basrah","Al Muthanna","Al Qadisiyyah","An Najaf","Arbil","As Sulaymaniyah","Babil","Baghdad","Dahuk","Dhi Qar","Diyala","Karbala","Maysan","Ninawa","Salah ad Din","Wasit"],
    "Ireland": ["Carlow","Cavan","Clare","Cork","Donegal","Dublin","Galway","Kerry","Kildare","Kilkenny","Laois","Leitrim","Limerick","Longford","Louth","Mayo","Meath","Monaghan","Offaly","Roscommon","Sligo","Tipperary","Waterford","Westmeath","Wexford","Wicklow"],
    "Denmark": ["Capital Region","Central Denmark","North Denmark","Region Zealand","Southern Denmark"],
    "Norway": ["Agder","Innlandet","More og Romsdal","Nordland","Oslo","Rogaland","Troms og Finnmark","Trondelag","Vestfold og Telemark","Vestland","Viken"],
    "Finland": ["Aland","Central Finland","Central Ostrobothnia","Kainuu","Lapland","North Karelia","North Ostrobothnia","North Savo","Ostrobothnia","Pirkanmaa","Satakunta","South Karelia","South Ostrobothnia","South Savo","Southwest Finland","Uusimaa"],
    "Zimbabwe": ["Bulawayo","Harare","Manicaland","Mashonaland Central","Mashonaland East","Mashonaland West","Masvingo","Matabeleland North","Matabeleland South","Midlands"],
    "Afghanistan": ["Badakhshan","Badghis","Baghlan","Balkh","Bamyan","Farah","Faryab","Ghazni","Ghor","Helmand","Herat","Kabul","Kandahar","Kapisa","Khost","Kunduz","Nangarhar","Paktia","Parwan","Takhar","Wardak","Zabul"],
    "Albania": ["Berat","Diber","Durres","Elbasan","Fier","Gjirokaster","Korce","Kukes","Lezhe","Shkoder","Tirana","Vlore"]
]

private let kAdultKeywords: Set<String> = [
    "sex","nude","naked","porn","xxx","adult","explicit","erotic","nsfw",
    "sexual","intercourse","fetish","strip","lingerie","seductive","obscene"
]
private let kViolenceKeywords: Set<String> = [
    "kill","murder","blood","gore","brutal","violent","violence","death",
    "shoot","shooting","stab","stabbing","weapon","gun","knife","bomb",
    "terror","terrorist","torture","assault","rape","abuse","massacre",
    "slaughter","decapitate","mutilate","genocide","execution"
]

// MARK: - Search Picker Sheet

struct AdSearchPickerSheet: View {
    let title: String
    let items: [String]
    let multiSelect: Bool
    @Binding var selectedSingle: String
    @Binding var selectedMultiple: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [String] {
        query.isEmpty ? items : items.filter { $0.lowercased().contains(query.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.self) { item in
                Button {
                    if multiSelect {
                        if selectedMultiple.contains(item) { selectedMultiple.remove(item) }
                        else { selectedMultiple.insert(item) }
                    } else {
                        selectedSingle = item
                        dismiss()
                    }
                } label: {
                    HStack {
                        Text(item)
                            .font(.custom("Inter18pt-Regular", size: 15))
                            .foregroundColor(.white)
                        Spacer()
                        let isSelected = multiSelect
                            ? selectedMultiple.contains(item)
                            : selectedSingle == item
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: Constant.themeColor))
                        }
                    }
                }
                .listRowBackground(Color(hex: "#1C1C1E"))
                .listRowSeparatorTint(Color(hex: "#3A3A3C"))
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "Search")
            .background(Color.black)
            .scrollContentBackground(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                if multiSelect {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                            .font(.custom("Inter18pt-SemiBold", size: 15))
                            .foregroundColor(Color(hex: Constant.themeColor))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - PostAdvertiseView

struct PostAdvertiseView: View {
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var selectedCountry = ""
    @State private var selectedStates: Set<String> = []
    @State private var selectedCategory = "Select Category"
    @State private var title = ""
    @State private var description = ""
    @State private var link = ""
    @State private var budget = ""
    @State private var duration = ""

    // Media
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    // Sheet toggles
    @State private var showCountryPicker = false
    @State private var showStatePicker = false
    @State private var showCategoryPicker = false

    // Posting
    @State private var isPosting = false
    @State private var errorMessage: String? = nil
    @State private var showSuccess = false

    // MARK: - Computed helpers

    private var currencySymbol: String { kCountryCurrency[selectedCountry] ?? "$" }
    private var tiers: [Int] { kCurrencyTiers[currencySymbol] ?? [3, 6, 12, 25] }
    private var statesForCountry: [String] { kCountryStates[selectedCountry] ?? [] }

    private var statesLabel: String {
        selectedStates.isEmpty ? "Select State(s)" : selectedStates.sorted().joined(separator: ", ")
    }

    private var isFlagged: Bool {
        let words = (title + " " + description)
            .lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return words.contains { kAdultKeywords.contains($0) || kViolenceKeywords.contains($0) }
    }

    private var canPost: Bool {
        !selectedCountry.isEmpty &&
        selectedCategory != "Select Category" &&
        !title.isEmpty && !description.isEmpty &&
        !budget.isEmpty && !duration.isEmpty &&
        !isFlagged && !isPosting
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Subtitle hint
                    Text("Reach more people by promoting your content as an ad.")
                        .font(.custom("Inter18pt-Regular", size: 13))
                        .foregroundColor(Color(hex: "#6E6E73"))
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 24)

                    // ── Select Country ──
                    fieldLabel("Select Country")
                    pickerRow(
                        text: selectedCountry.isEmpty ? "Select Country" : selectedCountry,
                        isPlaceholder: selectedCountry.isEmpty
                    ) { showCountryPicker = true }
                    .padding(.bottom, 18)

                    // ── Select State(s) ── shown only when country has states
                    if !statesForCountry.isEmpty {
                        fieldLabel("Select State(s)")
                        pickerRow(
                            text: selectedStates.isEmpty ? "Select State(s)" : statesLabel,
                            isPlaceholder: selectedStates.isEmpty
                        ) { showStatePicker = true }
                        .padding(.bottom, 18)
                    }

                    // ── Select Category ──
                    fieldLabel("Select Category")
                    pickerRow(
                        text: selectedCategory,
                        isPlaceholder: selectedCategory == "Select Category"
                    ) { showCategoryPicker = true }
                    .padding(.bottom, 18)

                    // ── Title ──
                    fieldLabel("Title")
                    darkTextField("Enter title", text: $title)
                        .padding(.bottom, 18)

                    // ── Description ──
                    fieldLabel("Description")
                    darkTextEditor(placeholder: "Enter description…", text: $description)
                        .padding(.bottom, 18)

                    // ── Link ──
                    fieldLabel("Link")
                    linkRow
                    Text("Optional — add a website or product link.")
                        .font(.custom("Inter18pt-Regular", size: 12))
                        .foregroundColor(Color(hex: "#6E6E73"))
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .padding(.bottom, 16)

                    // ── Daily Budget ──
                    fieldLabel("Daily Budget")
                    budgetRow
                        .padding(.bottom, 18)

                    // ── Ad Duration ──
                    fieldLabel("Ad Duration")
                    durationRow
                        .padding(.bottom, 18)

                    // ── Budget / Reach Table ──
                    reachTable
                        .padding(.bottom, 18)

                    // ── Media (optional) ──
                    fieldLabel("Media (optional)")
                    mediaPickerSection
                        .padding(.bottom, 18)

                    // ── 18+ Warning Banner ──
                    if isFlagged {
                        warningBanner
                            .padding(.bottom, 16)
                    }

                    // ── Error ──
                    if let err = errorMessage {
                        Text(err)
                            .font(.custom("Inter18pt-Regular", size: 13))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    // ── Post Button ──
                    postButton
                        .padding(.bottom, 40)
                }
            }
            .background(Color.black)
            .navigationTitle("Post Advertise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { autoSelectCountry() }
        .sheet(isPresented: $showCountryPicker) {
            AdSearchPickerSheet(
                title: "Select Country",
                items: kCountries,
                multiSelect: false,
                selectedSingle: $selectedCountry,
                selectedMultiple: .constant([])
            )
            .onDisappear {
                // Reset states when country changes
                selectedStates = []
            }
        }
        .sheet(isPresented: $showStatePicker) {
            AdSearchPickerSheet(
                title: "Select State(s)",
                items: statesForCountry,
                multiSelect: true,
                selectedSingle: .constant(""),
                selectedMultiple: $selectedStates
            )
        }
        .sheet(isPresented: $showCategoryPicker) {
            AdSearchPickerSheet(
                title: "Select Category",
                items: kCategories.filter { $0 != "Select Category" },
                multiSelect: false,
                selectedSingle: $selectedCategory,
                selectedMultiple: .constant([])
            )
        }
        .alert("Ad Posted!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your advertisement is now live and will appear to users in your selected region.")
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.custom("Inter18pt-Bold", size: 15))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private func pickerRow(text: String, isPlaceholder: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.custom("Inter18pt-Regular", size: 15))
                    .foregroundColor(isPlaceholder ? Color(hex: "#6E6E73") : .white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#6E6E73"))
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color(hex: "#1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func darkTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundColor(Color(hex: "#6E6E73")))
            .font(.custom("Inter18pt-Regular", size: 15))
            .foregroundColor(.white)
            .tint(.white)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color(hex: "#1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func darkTextEditor(placeholder: String, text: Binding<String>) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.custom("Inter18pt-Regular", size: 15))
                    .foregroundColor(Color(hex: "#6E6E73"))
                    .padding(.top, 14)
                    .padding(.leading, 16)
            }
            TextEditor(text: text)
                .font(.custom("Inter18pt-Regular", size: 15))
                .foregroundColor(.white)
                .tint(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100, maxHeight: 130)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var linkRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#6E6E73"))
            TextField("", text: $link,
                      prompt: Text("https://").foregroundColor(Color(hex: "#6E6E73")))
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(.white)
                .tint(.white)
                .keyboardType(.URL)
                .autocapitalization(.none)
            if !link.isEmpty {
                Button { link = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(hex: "#6E6E73"))
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var budgetRow: some View {
        HStack(spacing: 6) {
            Text(currencySymbol)
                .font(.custom("Inter18pt-SemiBold", size: 16))
                .foregroundColor(.white)
            TextField("", text: $budget,
                      prompt: Text("Enter amount").foregroundColor(Color(hex: "#6E6E73")))
                .font(.custom("Inter18pt-Regular", size: 15))
                .foregroundColor(.white)
                .tint(.white)
                .keyboardType(.decimalPad)
            Text("/ day")
                .font(.custom("Inter18pt-Regular", size: 13))
                .foregroundColor(Color(hex: "#6E6E73"))
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var durationRow: some View {
        HStack(spacing: 6) {
            TextField("", text: $duration,
                      prompt: Text("Number of days").foregroundColor(Color(hex: "#6E6E73")))
                .font(.custom("Inter18pt-Regular", size: 15))
                .foregroundColor(.white)
                .tint(.white)
                .keyboardType(.numberPad)
            Text("days")
                .font(.custom("Inter18pt-Regular", size: 13))
                .foregroundColor(Color(hex: "#6E6E73"))
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var reachTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Budget")
                    .font(.custom("Inter18pt-Bold", size: 12))
                    .foregroundColor(Color(hex: "#6E6E73"))
                Spacer()
                Text("Estimated Reach")
                    .font(.custom("Inter18pt-Bold", size: 12))
                    .foregroundColor(Color(hex: "#6E6E73"))
            }
            .padding(.bottom, 8)

            Divider().background(Color(hex: "#3A3A3C"))

            ForEach(Array(tiers.enumerated()), id: \.offset) { idx, tier in
                HStack {
                    Text("\(currencySymbol)\(formatNumber(tier))/day")
                        .font(.custom("Inter18pt-SemiBold", size: 13))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(formatNumber(tier * 2)) people")
                        .font(.custom("Inter18pt-Regular", size: 13))
                        .foregroundColor(Color(hex: "#A0A0A5"))
                }
                .frame(height: 38)

                if idx < tiers.count - 1 {
                    Divider().background(Color(hex: "#2A2A2E"))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var mediaPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 5,
                matching: .any(of: [.images, .videos])
            ) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: Constant.themeColor))
                    Text(selectedImages.isEmpty
                         ? "Add photos / videos"
                         : "\(selectedImages.count) selected")
                        .font(.custom("Inter18pt-Regular", size: 15))
                        .foregroundColor(selectedImages.isEmpty ? Color(hex: "#6E6E73") : .white)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color(hex: "#1C1C1E"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
            .onChange(of: selectedPhotos) { items in
                selectedImages = []
                for item in items {
                    item.loadTransferable(type: Data.self) { result in
                        if case .success(let data) = result,
                           let data = data,
                           let img = UIImage(data: data) {
                            DispatchQueue.main.async { selectedImages.append(img) }
                        }
                    }
                }
            }

            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { _, img in
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var warningBanner: some View {
        HStack(spacing: 10) {
            Text("18+")
                .font(.custom("Inter18pt-Bold", size: 12))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text("This post may contain adult or violent content.")
                .font(.custom("Inter18pt-Regular", size: 13))
                .foregroundColor(Color(hex: "#FF453A"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "#FF453A").opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#FF453A").opacity(0.4), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var postButton: some View {
        Button { postAd() } label: {
            ZStack {
                if isPosting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Post")
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(canPost ? Color(hex: Constant.themeColor) : Color(hex: "#3A3A3C"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .disabled(!canPost)
        .opacity(canPost ? 1 : 0.4)
    }

    // MARK: - Helpers

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func autoSelectCountry() {
        let dialCode = UserDefaults.standard.string(forKey: Constant.country_Code) ?? ""
        guard !dialCode.isEmpty else { return }
        if let country = kDialToCountry[dialCode] {
            selectedCountry = country
        } else {
            // prefix match (e.g. "+1" shared codes)
            for (code, country) in kDialToCountry {
                if dialCode.hasPrefix(code) || code.hasPrefix(dialCode) {
                    selectedCountry = country
                    break
                }
            }
        }
    }

    // MARK: - Post action

    private func postAd() {
        guard !selectedCountry.isEmpty else { errorMessage = "Please select a country."; return }
        guard selectedCategory != "Select Category" else { errorMessage = "Please select a category."; return }
        guard !title.isEmpty else { errorMessage = "Title is required."; return }
        guard !description.isEmpty else { errorMessage = "Description is required."; return }
        guard !budget.isEmpty else { errorMessage = "Daily budget is required."; return }
        guard !duration.isEmpty else { errorMessage = "Ad duration is required."; return }

        // Minimum budget validation
        if let budgetVal = Double(budget) {
            let minBudget = Double(tiers.first ?? 1)
            if budgetVal < minBudget {
                errorMessage = "Minimum budget is \(currencySymbol)\(tiers.first ?? 1)"
                return
            }
        }

        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        guard !uid.isEmpty else { errorMessage = "Not logged in."; return }

        isPosting = true
        errorMessage = nil

        let states = selectedStates.sorted().joined(separator: ",")
        let mediaData = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }

        ApiService.shared.postAdvertisement(
            uid: uid, country: selectedCountry, category: selectedCategory,
            title: title, description: description, link: link,
            budget: budget, duration: duration, mediaData: mediaData
        ) { success, message in
            DispatchQueue.main.async {
                isPosting = false
                if success { showSuccess = true } else { errorMessage = message }
            }
        }
    }
}
