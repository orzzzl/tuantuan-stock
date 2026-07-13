/// A curated colloquial short name pair for one symbol (task 25).
typedef CompanyShortName = ({String zh, String en});

/// Curated short name for [symbol], or null: unmapped symbols fall back to
/// [shortenCompanyName] over the provider name. Colloquial beats legal
/// ("谷歌" over "Alphabet"), hand-checked per entry; the pack covers every
/// bundled-logo symbol, the index strip, and the top-ETF universe (task 28).
CompanyShortName? companyShortName(String symbol) => companyShortNames[symbol];

/// The full curated pack, keyed by app symbol; exposed so tests can verify
/// coverage, non-emptiness, and uniqueness.
const companyShortNames = <String, CompanyShortName>{
  '^GSPC': (zh: '标普500', en: 'S&P 500'),
  '^IXIC': (zh: '纳斯达克', en: 'Nasdaq'),
  '^DJI': (zh: '道琼斯', en: 'Dow Jones'),
  'AAPL': (zh: '苹果', en: 'Apple'),
  'ABBV': (zh: '艾伯维', en: 'AbbVie'),
  'ABT': (zh: '雅培', en: 'Abbott'),
  'ACN': (zh: '埃森哲', en: 'Accenture'),
  'ADBE': (zh: 'Adobe', en: 'Adobe'),
  'ADP': (zh: 'ADP', en: 'ADP'),
  'AGG': (zh: '安硕全债市', en: 'iShares Core Bond'),
  'AMAT': (zh: '应用材料', en: 'Applied Materials'),
  'AMD': (zh: 'AMD', en: 'AMD'),
  'AMZN': (zh: '亚马逊', en: 'Amazon'),
  'ANET': (zh: 'Arista', en: 'Arista'),
  'ARKK': (zh: '方舟创新 ETF', en: 'ARK Innovation'),
  'ARM': (zh: 'Arm', en: 'Arm'),
  'ASHR': (zh: '沪深300 ETF', en: 'CSI 300 ETF'),
  'ASML': (zh: '阿斯麦', en: 'ASML'),
  'AVGO': (zh: '博通', en: 'Broadcom'),
  'AXP': (zh: '美国运通', en: 'Amex'),
  'BABA': (zh: '阿里巴巴', en: 'Alibaba'),
  'BAC': (zh: '美国银行', en: 'Bank of America'),
  'BIL': (zh: '1-3月国库券', en: '1-3 Mo T-Bill'),
  'BITO': (zh: '比特币期货 ETF', en: 'Bitcoin Futures ETF'),
  'BKNG': (zh: '缤客', en: 'Booking'),
  'BMY': (zh: '百时美施贵宝', en: 'Bristol Myers'),
  'BND': (zh: '全债市 ETF', en: 'Total Bond ETF'),
  'BRK.A': (zh: '伯克希尔-A', en: 'Berkshire A'),
  'BRK.B': (zh: '伯克希尔-B', en: 'Berkshire B'),
  'C': (zh: '花旗', en: 'Citi'),
  'CAT': (zh: '卡特彼勒', en: 'Caterpillar'),
  'COIN': (zh: 'Coinbase', en: 'Coinbase'),
  'CRM': (zh: '赛富时', en: 'Salesforce'),
  'CVS': (zh: 'CVS', en: 'CVS'),
  'CVX': (zh: '雪佛龙', en: 'Chevron'),
  'DASH': (zh: 'DoorDash', en: 'DoorDash'),
  'DELL': (zh: '戴尔', en: 'Dell'),
  'DIA': (zh: '道指 ETF', en: 'Dow Jones ETF'),
  'DIS': (zh: '迪士尼', en: 'Disney'),
  'ELV': (zh: 'Elevance', en: 'Elevance'),
  'ETHA': (zh: '贝莱德以太坊', en: 'iShares Ethereum'),
  'EWJ': (zh: '日本 ETF', en: 'Japan ETF'),
  'F': (zh: '福特', en: 'Ford'),
  'FBTC': (zh: '富达比特币', en: 'Fidelity Bitcoin'),
  'FDX': (zh: '联邦快递', en: 'FedEx'),
  'FXI': (zh: '富时中国50', en: 'China Large Cap'),
  'GBTC': (zh: '灰度比特币', en: 'Grayscale Bitcoin'),
  'GDX': (zh: '金矿股 ETF', en: 'Gold Miners ETF'),
  'GE': (zh: '通用电气', en: 'GE'),
  'GILD': (zh: '吉利德', en: 'Gilead'),
  'GLD': (zh: '黄金 ETF', en: 'Gold ETF'),
  'GM': (zh: '通用汽车', en: 'GM'),
  'GOOG': (zh: '谷歌-C', en: 'Google C'),
  'GOOGL': (zh: '谷歌-A', en: 'Google A'),
  'GS': (zh: '高盛', en: 'Goldman Sachs'),
  'HD': (zh: '家得宝', en: 'Home Depot'),
  'HON': (zh: '霍尼韦尔', en: 'Honeywell'),
  'HOOD': (zh: 'Robinhood', en: 'Robinhood'),
  'HPQ': (zh: '惠普', en: 'HP'),
  'HYG': (zh: '高收益债 ETF', en: 'High Yield Bond'),
  'IAU': (zh: '安硕黄金', en: 'iShares Gold'),
  'IBB': (zh: '安硕生物科技', en: 'iShares Biotech'),
  'IBIT': (zh: '贝莱德比特币', en: 'iShares Bitcoin'),
  'IBM': (zh: 'IBM', en: 'IBM'),
  'IEF': (zh: '7-10年美债', en: '7-10 Yr Treasury'),
  'INDA': (zh: '印度 ETF', en: 'India ETF'),
  'INTC': (zh: '英特尔', en: 'Intel'),
  'INTU': (zh: 'Intuit', en: 'Intuit'),
  'ISRG': (zh: '直觉外科', en: 'Intuitive'),
  'ITOT': (zh: '安硕全市场', en: 'iShares Total Market'),
  'IVV': (zh: '安硕标普500', en: 'iShares S&P 500'),
  'IWM': (zh: '罗素2000 ETF', en: 'Russell 2000 ETF'),
  'JD': (zh: '京东', en: 'JD.com'),
  'JEPI': (zh: '摩根月派息', en: 'JPM Equity Income'),
  'JEPQ': (zh: '摩根纳指月派息', en: 'JPM Nasdaq Income'),
  'JNJ': (zh: '强生', en: 'Johnson & Johnson'),
  'JPM': (zh: '摩根大通', en: 'JPMorgan'),
  'KO': (zh: '可口可乐', en: 'Coca-Cola'),
  'KRE': (zh: '区域银行 ETF', en: 'Regional Banks ETF'),
  'KWEB': (zh: '中概互联网 ETF', en: 'China Internet ETF'),
  'LCID': (zh: 'Lucid', en: 'Lucid'),
  'LIN': (zh: '林德', en: 'Linde'),
  'LLY': (zh: '礼来', en: 'Eli Lilly'),
  'LQD': (zh: '投资级公司债', en: 'IG Corporate Bond'),
  'LRCX': (zh: '拉姆研究', en: 'Lam Research'),
  'MA': (zh: '万事达', en: 'Mastercard'),
  'MCD': (zh: '麦当劳', en: "McDonald's"),
  'MCHI': (zh: 'MSCI中国 ETF', en: 'MSCI China ETF'),
  'MDT': (zh: '美敦力', en: 'Medtronic'),
  'META': (zh: 'Meta', en: 'Meta'),
  'MMC': (zh: '威达信', en: 'Marsh McLennan'),
  'MO': (zh: '奥驰亚', en: 'Altria'),
  'MOAT': (zh: '宽护城河 ETF', en: 'Wide Moat ETF'),
  'MRK': (zh: '默沙东', en: 'Merck'),
  'MRNA': (zh: '莫德纳', en: 'Moderna'),
  'MRVL': (zh: '迈威尔', en: 'Marvell'),
  'MS': (zh: '摩根士丹利', en: 'Morgan Stanley'),
  'MSFT': (zh: '微软', en: 'Microsoft'),
  'MU': (zh: '美光', en: 'Micron'),
  'NFLX': (zh: '奈飞', en: 'Netflix'),
  'NIO': (zh: '蔚来', en: 'NIO'),
  'NKE': (zh: '耐克', en: 'Nike'),
  'NOW': (zh: 'ServiceNow', en: 'ServiceNow'),
  'NVDA': (zh: '英伟达', en: 'NVIDIA'),
  'NVDL': (zh: '英伟达两倍做多', en: 'NVDA 2X Long'),
  'ORCL': (zh: '甲骨文', en: 'Oracle'),
  'PEP': (zh: '百事', en: 'Pepsi'),
  'PFE': (zh: '辉瑞', en: 'Pfizer'),
  'PG': (zh: '宝洁', en: 'P&G'),
  'PLD': (zh: '安博', en: 'Prologis'),
  'PLTR': (zh: 'Palantir', en: 'Palantir'),
  'PM': (zh: '菲利普莫里斯', en: 'Philip Morris'),
  'PSQ': (zh: '纳指反向 ETF', en: 'Short QQQ'),
  'PYPL': (zh: 'PayPal', en: 'PayPal'),
  'QCOM': (zh: '高通', en: 'Qualcomm'),
  'QLD': (zh: '纳指两倍做多', en: 'Ultra QQQ'),
  'QQQ': (zh: '纳指100 ETF', en: 'Nasdaq 100 ETF'),
  'QQQM': (zh: '迷你纳指100', en: 'Nasdaq 100 Mini'),
  'RBLX': (zh: 'Roblox', en: 'Roblox'),
  'RIVN': (zh: 'Rivian', en: 'Rivian'),
  'RSP': (zh: '标普500等权', en: 'S&P 500 Equal Weight'),
  'RTX': (zh: '雷神', en: 'RTX'),
  'SBUX': (zh: '星巴克', en: 'Starbucks'),
  'SCHD': (zh: '嘉信红利 ETF', en: 'Schwab Dividend'),
  'SCHW': (zh: '嘉信理财', en: 'Charles Schwab'),
  'SDS': (zh: '标普两倍做空', en: 'UltraShort S&P 500'),
  'SGOV': (zh: '0-3月国库券', en: '0-3 Mo T-Bill'),
  'SHOP': (zh: 'Shopify', en: 'Shopify'),
  'SHY': (zh: '1-3年美债', en: '1-3 Yr Treasury'),
  'SLV': (zh: '白银 ETF', en: 'Silver ETF'),
  'SMH': (zh: '半导体 ETF', en: 'Semiconductor ETF'),
  'SNOW': (zh: 'Snowflake', en: 'Snowflake'),
  'SOFI': (zh: 'SoFi', en: 'SoFi'),
  'SOXL': (zh: '半导体三倍做多', en: 'Semis Bull 3X'),
  'SOXS': (zh: '半导体三倍做空', en: 'Semis Bear 3X'),
  'SOXX': (zh: '安硕半导体', en: 'iShares Semiconductor'),
  'SPGI': (zh: '标普全球', en: 'S&P Global'),
  'SPXL': (zh: '标普500三倍牛', en: 'S&P 500 Bull 3X'),
  'SPXS': (zh: '标普500三倍熊', en: 'S&P 500 Bear 3X'),
  'SPXU': (zh: '标普三倍做空', en: 'UltraPro Short S&P'),
  'SPY': (zh: '标普500 ETF', en: 'SPDR S&P 500'),
  'SQQQ': (zh: '纳指三倍做空', en: 'UltraPro Short QQQ'),
  'SSO': (zh: '标普两倍做多', en: 'Ultra S&P 500'),
  'SYK': (zh: '史赛克', en: 'Stryker'),
  'T': (zh: 'AT&T', en: 'AT&T'),
  'TIP': (zh: '通胀保值债', en: 'TIPS ETF'),
  'TLT': (zh: '20年+美债', en: '20+ Yr Treasury'),
  'TMF': (zh: '美债三倍做多', en: 'Treasury Bull 3X'),
  'TNA': (zh: '罗素2000三倍多', en: 'Small Cap Bull 3X'),
  'TQQQ': (zh: '纳指三倍做多', en: 'UltraPro QQQ'),
  'TSLA': (zh: '特斯拉', en: 'Tesla'),
  'TSLL': (zh: '特斯拉两倍做多', en: 'Tesla Bull 2X'),
  'TSM': (zh: '台积电', en: 'TSMC'),
  'TXN': (zh: '德州仪器', en: 'Texas Instruments'),
  'TZA': (zh: '罗素2000三倍空', en: 'Small Cap Bear 3X'),
  'UBER': (zh: '优步', en: 'Uber'),
  'UNH': (zh: '联合健康', en: 'UnitedHealth'),
  'UNP': (zh: '联合太平洋', en: 'Union Pacific'),
  'UPRO': (zh: '标普三倍做多', en: 'UltraPro S&P 500'),
  'UPS': (zh: 'UPS', en: 'UPS'),
  'USO': (zh: '原油 ETF', en: 'US Oil Fund'),
  'UVXY': (zh: '恐慌指数1.5倍', en: 'Ultra VIX 1.5X'),
  'V': (zh: 'Visa', en: 'Visa'),
  'VEA': (zh: '发达市场 ETF', en: 'Developed Markets'),
  'VGT': (zh: '先锋科技 ETF', en: 'Vanguard Tech'),
  'VIG': (zh: '股息增长 ETF', en: 'Dividend Growth'),
  'VNQ': (zh: '房地产 ETF', en: 'Real Estate ETF'),
  'VOO': (zh: '先锋标普500', en: 'Vanguard S&P 500'),
  'VRTX': (zh: '福泰制药', en: 'Vertex'),
  'VT': (zh: '全球股市 ETF', en: 'Total World ETF'),
  'VTI': (zh: '全市场 ETF', en: 'Total Market ETF'),
  'VTV': (zh: '先锋价值股', en: 'Vanguard Value'),
  'VUG': (zh: '先锋成长股', en: 'Vanguard Growth'),
  'VWO': (zh: '新兴市场 ETF', en: 'Emerging Markets'),
  'VXX': (zh: '恐慌指数期货', en: 'VIX Futures'),
  'VYM': (zh: '高股息 ETF', en: 'High Dividend'),
  'WFC': (zh: '富国银行', en: 'Wells Fargo'),
  'WMT': (zh: '沃尔玛', en: 'Walmart'),
  'XBI': (zh: '生物科技 ETF', en: 'Biotech ETF'),
  'XLE': (zh: '能源板块 ETF', en: 'Energy Sector ETF'),
  'XLF': (zh: '金融板块 ETF', en: 'Financial Sector ETF'),
  'XLI': (zh: '工业板块 ETF', en: 'Industrial Sector ETF'),
  'XLK': (zh: '科技板块 ETF', en: 'Tech Sector ETF'),
  'XLP': (zh: '必需消费 ETF', en: 'Staples Sector ETF'),
  'XLU': (zh: '公用事业 ETF', en: 'Utilities Sector ETF'),
  'XLV': (zh: '医疗板块 ETF', en: 'Health Sector ETF'),
  'XLY': (zh: '可选消费 ETF', en: 'Discretionary ETF'),
  'XOM': (zh: '埃克森美孚', en: 'Exxon Mobil'),
  'XOP': (zh: '油气开采 ETF', en: 'Oil & Gas ETF'),
  'XYZ': (zh: 'Block', en: 'Block'),
  'YANG': (zh: '中国三倍做空', en: 'China Bear 3X'),
  'YINN': (zh: '中国三倍做多', en: 'China Bull 3X'),
};

/// Legal-suffix words stripped (repeatedly) from the tail of an English
/// provider name. Only clearly-legal boilerplate — never leading words.
const _enLegalSuffixes = {
  'inc',
  'incorporated',
  'corp',
  'corporation',
  'co',
  'ltd',
  'holdings',
  'group',
  'plc',
};

/// Share-class tails like `-CL A`, `CL B`, `Class A` at the end of an
/// English provider name.
final _enClassTail = RegExp(
  r'[\s\-]+cl(?:ass)?\s+[a-c]$',
  caseSensitive: false,
);

/// Trailing separators/punctuation left behind once a suffix is stripped
/// (`JPMorgan Chase & Co` → `JPMorgan Chase &` → `JPMorgan Chase`).
final _enTrailingJunk = RegExp(r'[\s.,;&\-]+$');

/// Legal tails stripped from a Chinese provider name, longest first. `集团`
/// stays — it is part of how people say the name (阿里巴巴集团).
const _zhLegalSuffixes = ['控股有限公司', '股份有限公司', '有限公司', '公司'];

/// Fund-name marker gating the ETF issuer rules (task 28): only names that
/// identify themselves as funds get issuer boilerplate stripped, so plain
/// company names (even ones containing "Trust") pass through the company path
/// untouched by the fund rules.
final _enFundMarker = RegExp(
  r'\b(etf|fund|trust|tr|shares)\b',
  caseSensitive: false,
);

/// Leading issuer/trust boilerplate on English ETF legal names (task 28) —
/// these put the issuer first, so plain truncation kept "Proshares Trust …"
/// and dropped the distinguishing part. Stripped repeatedly ("VanEck ETF Tr
/// VanEck Morningstar …" sheds both layers).
final _enIssuerPrefixes = [
  RegExp(r'^proshares(\s+trust)?\s+', caseSensitive: false),
  RegExp(
    r'^direxion(\s+shares(\s+etf\s+trust)?)?(\s+daily)?\s+',
    caseSensitive: false,
  ),
  RegExp(r'^vaneck(\s+etf\s+tr(ust)?|\s+vectors)?\s+', caseSensitive: false),
  RegExp(
    r'^(state\s+street\s+)?spdr(\s+series\s+trust)?\s+',
    caseSensitive: false,
  ),
  RegExp(r'^ishares(\s+trust|\s+inc)?\s+', caseSensitive: false),
  RegExp(r'^vanguard\s+', caseSensitive: false),
  RegExp(r'^invesco\s+', caseSensitive: false),
  RegExp(r'^schwab(\s+strategic\s+trust)?\s+', caseSensitive: false),
  RegExp(r'^fidelity\s+', caseSensitive: false),
  RegExp(r'^wisdomtree(\s+trust)?\s+', caseSensitive: false),
  RegExp(r'^first\s+trust\s+', caseSensitive: false),
  RegExp(r'^global\s+x(\s+funds)?\s+', caseSensitive: false),
  RegExp(r'^graniteshares(\s+etf\s+trust)?\s+', caseSensitive: false),
];

/// A remainder made only of fund-wrapper words ("Trust", "ETF Shares") means
/// the prefix strip ate the whole identity — reject it and keep the original.
final _enOnlyBoilerplate = RegExp(
  r'^(?:(?:etf|fund|trust|tr|shares)\s*)+$',
  caseSensitive: false,
);

/// Sector-SPDR names carry the issuer in the tail instead
/// ("Technology Select Sector SPDR Fund" → "Technology").
final _enSectorSpdrTail = RegExp(
  r'\s+select\s+sector\s+spdr(\s+fund)?$',
  caseSensitive: false,
);

/// "… ETF Trust" → "… ETF" and "… 3X Shares" → "… 3X": drop the legal wrapper
/// word but keep the part that identifies the fund.
final _enEtfTrustTail = RegExp(r'(\s+etf)\s+tr(ust)?$', caseSensitive: false);
final _enLeverageSharesTail = RegExp(
  r'(\s+\d+x)\s+shares$',
  caseSensitive: false,
);

/// zh fund names lead with a latin issuer ("VanEck Vectors晨星…") — no space
/// before the CJK part, hence the `\s*` tails.
final _zhIssuerPrefixes = [
  RegExp(r'^proshares\s*', caseSensitive: false),
  RegExp(r'^direxion(\s+daily)?\s*', caseSensitive: false),
  RegExp(r'^vaneck(\s+etf\s+tr(ust)?|\s+vectors)?\s*', caseSensitive: false),
  RegExp(r'^(state\s+street\s+)?spdr\s*', caseSensitive: false),
  RegExp(r'^ishares\s*', caseSensitive: false),
  RegExp(r'^vanguard\s*', caseSensitive: false),
  RegExp(r'^invesco\s*', caseSensitive: false),
];

/// zh `-发行商` tail ("标普500指数ETF-SPDR" → "标普500指数ETF").
final _zhIssuerTail = RegExp(r'-[A-Za-z][A-Za-z0-9&. ]*$');

/// Second-tier fallback for symbols without a curated entry: conservatively
/// strips legal boilerplate from the provider [name]. Returns [name]
/// unchanged when stripping would leave nothing.
String shortenCompanyName(String name, {required bool chinese}) {
  final trimmed = name.trim();
  final shortened = chinese ? _shortenZh(trimmed) : _shortenEn(trimmed);
  return shortened.isEmpty ? trimmed : shortened;
}

String _shortenEn(String name) {
  var current = name;
  if (_enFundMarker.hasMatch(current)) {
    current = _stripEnFundBoilerplate(current);
  }
  while (true) {
    var next = current.replaceFirst(_enClassTail, '');
    next = next.replaceFirst(_enTrailingJunk, '');
    final lastSpace = next.lastIndexOf(' ');
    if (lastSpace > 0) {
      final lastWord = next.substring(lastSpace + 1).toLowerCase();
      if (_enLegalSuffixes.contains(lastWord)) {
        next = next.substring(0, lastSpace);
      }
    }
    if (next == current) return current;
    current = next;
  }
}

String _stripEnFundBoilerplate(String name) {
  var current = name;
  var stripped = true;
  while (stripped) {
    stripped = false;
    for (final prefix in _enIssuerPrefixes) {
      final next = current.replaceFirst(prefix, '');
      if (next != current &&
          next.isNotEmpty &&
          !_enOnlyBoilerplate.hasMatch(next)) {
        current = next;
        stripped = true;
      }
    }
  }
  final withoutSector = current.replaceFirst(_enSectorSpdrTail, '');
  if (withoutSector.isNotEmpty) current = withoutSector;
  current = current.replaceFirstMapped(_enEtfTrustTail, (m) => m[1]!);
  current = current.replaceFirstMapped(_enLeverageSharesTail, (m) => m[1]!);
  return current;
}

String _shortenZh(String name) {
  var current = name;
  if (current.contains('ETF') || current.contains('基金')) {
    current = _stripZhFundBoilerplate(current);
  }
  for (final suffix in _zhLegalSuffixes) {
    if (current.length > suffix.length && current.endsWith(suffix)) {
      return current.substring(0, current.length - suffix.length).trim();
    }
  }
  return current;
}

String _stripZhFundBoilerplate(String name) {
  var current = name;
  for (final prefix in _zhIssuerPrefixes) {
    final next = current.replaceFirst(prefix, '');
    if (next != current && next.isNotEmpty) {
      current = next;
      break;
    }
  }
  final withoutTail = current.replaceFirst(_zhIssuerTail, '');
  if (withoutTail.isNotEmpty) current = withoutTail;
  return current;
}
