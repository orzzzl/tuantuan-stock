# Provider v2 fixtures (task 16)

Live captures from `qt.gtimg.cn` / `hq.sinajs.cn` / `web.ifzq.gtimg.cn` /
`stock.finance.sina.com.cn` / `suggest3.sinajs.cn`, taken 2026-07-08 05:15–05:25 UTC
(2026-07-07 22:15 PDT; US market closed — last regular session ended 2026-07-07
16:00 EDT). Files ending in `.gbk.txt` are **raw GBK bytes, do not re-encode** —
mapping tests in tasks 17/18 must decode them with the chosen GBK decoder.
See `docs/provider-report-v2.md` for the field maps and analysis.

| File | What | Command |
|------|------|---------|
| `tencent_quote_batch.gbk.txt` | Tencent batch quote AAPL, MSFT, BRK.B | `curl 'https://qt.gtimg.cn/q=usAAPL,usMSFT,usBRK.B'` |
| `sina_quote_batch.gbk.txt` | Sina batch quote incl. BRK.B failure evidence | `curl -H 'Referer: https://finance.sina.com.cn' 'https://hq.sinajs.cn/list=gb_aapl,gb_msft,gb_brk.b,gb_brkb'` |
| `tencent_quote_batch50.gbk.txt` | 50 symbols in one Tencent call | same, `q=usAAPL,...` ×50 |
| `sina_quote_batch50.gbk.txt` | 50 symbols in one Sina call (49 filled; BRK.B empty) | same, `list=gb_aapl,...` ×50 |
| `tencent_kline_day.json` | Tencent daily kline, 320 bars, qfq | `curl 'https://web.ifzq.gtimg.cn/appstock/app/usfqkline/get?param=usAAPL.OQ,day,,,320,qfq'` |
| `tencent_kline_week.json` | Tencent weekly kline, 320 bars | same, `week` |
| `tencent_kline_month.json` | Tencent monthly kline, 233 bars (all history) | same, `month` |
| `sina_min5.jsonp.txt` | Sina 5-min bars, 14 trading days | `curl -H 'Referer: ...' 'https://stock.finance.sina.com.cn/usstock/api/jsonp.php/cb/US_MinKService.getMinK?symbol=aapl&type=5'` |
| `sina_daily_full.jsonp.txt` | Sina full daily history since 1984 (934 KB — the "heavy payload" evidence) | same base, `US_MinKService.getDailyK?symbol=aapl` |
| `sina_suggest_apple.gbk.txt` | Search suggest, English query | `curl -H 'Referer: ...' 'https://suggest3.sinajs.cn/suggest/type=41&key=apple'` |
| `sina_suggest_pingguo.gbk.txt` | Search suggest, Chinese query 苹果 | same, `key=%E8%8B%B9%E6%9E%9C` |
| `tencent_quote_indices.gbk.txt` | Tencent index quotes DJI, IXIC, INX | `curl 'https://qt.gtimg.cn/q=usDJI,usIXIC,usINX'` |
| `tencent_index_probe.gbk.txt` | S&P symbol probe (`usSPX`/`usGSPC` → `pv_none_match`) | `curl 'https://qt.gtimg.cn/q=usDJI,usIXIC,usINX,usSPX,us.INX,us.SPX,usGSPC'` |
| `sina_int_indices.gbk.txt` | Sina `int_` indices — **stale, do-not-use evidence** | `curl -H 'Referer: ...' 'https://hq.sinajs.cn/list=int_dji,int_nasdaq,int_sp500'` |
| `tencent_kline_day1_premarket.json` | PRE-market (2026-07-08 04:12 EDT) kline w/ `USB_open_盘前交易` token | `curl 'https://web.ifzq.gtimg.cn/appstock/app/usfqkline/get?param=usAAPL.OQ,day,,,1,qfq'` |
| `tencent_quote_aapl_premarket.gbk.txt` | PRE-market Tencent quote — no ext price (fields 3/30 stay at last close) | `curl 'https://qt.gtimg.cn/q=usAAPL'` |
| `sina_quote_aapl_premarket.gbk.txt` | PRE-market Sina quote — live ext price, field 24 = sample minute | `curl -H 'Referer: ...' 'https://hq.sinajs.cn/list=gb_aapl'` |

This retires the v0.1 note (PR #13) about synthetic candle fixtures: chart mapping
tests can now run against these live captures.
