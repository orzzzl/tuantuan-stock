/// A curated colloquial short name pair for one symbol (task 25).
typedef CompanyShortName = ({String zh, String en});

/// Curated short name for [symbol], or null: unmapped symbols fall back to
/// [shortenCompanyName] over the provider name. Colloquial beats legal
/// ("谷歌" over "Alphabet"), hand-checked per entry; the pack covers every
/// bundled-logo symbol plus the index strip.
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
  'AMAT': (zh: '应用材料', en: 'Applied Materials'),
  'AMD': (zh: 'AMD', en: 'AMD'),
  'AMZN': (zh: '亚马逊', en: 'Amazon'),
  'ANET': (zh: 'Arista', en: 'Arista'),
  'ARM': (zh: 'Arm', en: 'Arm'),
  'ASML': (zh: '阿斯麦', en: 'ASML'),
  'AVGO': (zh: '博通', en: 'Broadcom'),
  'AXP': (zh: '美国运通', en: 'Amex'),
  'BABA': (zh: '阿里巴巴', en: 'Alibaba'),
  'BAC': (zh: '美国银行', en: 'Bank of America'),
  'BKNG': (zh: '缤客', en: 'Booking'),
  'BMY': (zh: '百时美施贵宝', en: 'Bristol Myers'),
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
  'DIS': (zh: '迪士尼', en: 'Disney'),
  'ELV': (zh: 'Elevance', en: 'Elevance'),
  'F': (zh: '福特', en: 'Ford'),
  'FDX': (zh: '联邦快递', en: 'FedEx'),
  'GE': (zh: '通用电气', en: 'GE'),
  'GILD': (zh: '吉利德', en: 'Gilead'),
  'GM': (zh: '通用汽车', en: 'GM'),
  'GOOG': (zh: '谷歌-C', en: 'Google C'),
  'GOOGL': (zh: '谷歌-A', en: 'Google A'),
  'GS': (zh: '高盛', en: 'Goldman Sachs'),
  'HD': (zh: '家得宝', en: 'Home Depot'),
  'HON': (zh: '霍尼韦尔', en: 'Honeywell'),
  'HOOD': (zh: 'Robinhood', en: 'Robinhood'),
  'HPQ': (zh: '惠普', en: 'HP'),
  'IBM': (zh: 'IBM', en: 'IBM'),
  'INTC': (zh: '英特尔', en: 'Intel'),
  'INTU': (zh: 'Intuit', en: 'Intuit'),
  'ISRG': (zh: '直觉外科', en: 'Intuitive'),
  'IWM': (zh: '罗素2000 ETF', en: 'Russell 2000 ETF'),
  'JD': (zh: '京东', en: 'JD.com'),
  'JNJ': (zh: '强生', en: 'Johnson & Johnson'),
  'JPM': (zh: '摩根大通', en: 'JPMorgan'),
  'KO': (zh: '可口可乐', en: 'Coca-Cola'),
  'LCID': (zh: 'Lucid', en: 'Lucid'),
  'LIN': (zh: '林德', en: 'Linde'),
  'LLY': (zh: '礼来', en: 'Eli Lilly'),
  'LRCX': (zh: '拉姆研究', en: 'Lam Research'),
  'MA': (zh: '万事达', en: 'Mastercard'),
  'MCD': (zh: '麦当劳', en: "McDonald's"),
  'MDT': (zh: '美敦力', en: 'Medtronic'),
  'META': (zh: 'Meta', en: 'Meta'),
  'MMC': (zh: '威达信', en: 'Marsh McLennan'),
  'MO': (zh: '奥驰亚', en: 'Altria'),
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
  'ORCL': (zh: '甲骨文', en: 'Oracle'),
  'PEP': (zh: '百事', en: 'Pepsi'),
  'PFE': (zh: '辉瑞', en: 'Pfizer'),
  'PG': (zh: '宝洁', en: 'P&G'),
  'PLD': (zh: '安博', en: 'Prologis'),
  'PLTR': (zh: 'Palantir', en: 'Palantir'),
  'PM': (zh: '菲利普莫里斯', en: 'Philip Morris'),
  'PYPL': (zh: 'PayPal', en: 'PayPal'),
  'QCOM': (zh: '高通', en: 'Qualcomm'),
  'QQQ': (zh: '纳指100 ETF', en: 'Nasdaq 100 ETF'),
  'RBLX': (zh: 'Roblox', en: 'Roblox'),
  'RIVN': (zh: 'Rivian', en: 'Rivian'),
  'RTX': (zh: '雷神', en: 'RTX'),
  'SBUX': (zh: '星巴克', en: 'Starbucks'),
  'SCHW': (zh: '嘉信理财', en: 'Charles Schwab'),
  'SHOP': (zh: 'Shopify', en: 'Shopify'),
  'SNOW': (zh: 'Snowflake', en: 'Snowflake'),
  'SOFI': (zh: 'SoFi', en: 'SoFi'),
  'SPGI': (zh: '标普全球', en: 'S&P Global'),
  'SYK': (zh: '史赛克', en: 'Stryker'),
  'T': (zh: 'AT&T', en: 'AT&T'),
  'TSLA': (zh: '特斯拉', en: 'Tesla'),
  'TSM': (zh: '台积电', en: 'TSMC'),
  'TXN': (zh: '德州仪器', en: 'Texas Instruments'),
  'UBER': (zh: '优步', en: 'Uber'),
  'UNH': (zh: '联合健康', en: 'UnitedHealth'),
  'UNP': (zh: '联合太平洋', en: 'Union Pacific'),
  'UPS': (zh: 'UPS', en: 'UPS'),
  'V': (zh: 'Visa', en: 'Visa'),
  'VOO': (zh: '标普500 ETF', en: 'S&P 500 ETF'),
  'VRTX': (zh: '福泰制药', en: 'Vertex'),
  'VTI': (zh: '全市场 ETF', en: 'Total Market ETF'),
  'WFC': (zh: '富国银行', en: 'Wells Fargo'),
  'WMT': (zh: '沃尔玛', en: 'Walmart'),
  'XOM': (zh: '埃克森美孚', en: 'Exxon Mobil'),
  'XYZ': (zh: 'Block', en: 'Block'),
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

String _shortenZh(String name) {
  for (final suffix in _zhLegalSuffixes) {
    if (name.length > suffix.length && name.endsWith(suffix)) {
      return name.substring(0, name.length - suffix.length).trim();
    }
  }
  return name;
}
