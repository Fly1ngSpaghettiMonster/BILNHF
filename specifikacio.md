# NagyHF Specifikáció — Kiskereskedelmi Értékesítés Intelligencia

## Bemutatás

A félévi nagy házi feladat célja egy kiskereskedelmi értékesítési adatokat feldolgozó üzleti intelligencia megoldás elkészítése. A rendszer két adatforrásból dolgozik: az elsődleges adatforrás a Kaggle-ről származó **Superstore Sales** adathalmaz (~10 000 rendelés, amely tartalmazza a rendelések dátumát, vásárlói szegmenst, régiót, államot, termékkategóriát, eladási összeget, mennyiséget, kedvezményt és profitot), a másodlagos adatforrás pedig az **USA ünnepnapok naptára** (US Public Holidays), amely dimenzióként gazdagítja az értékesítési adatokat szezonális információkkal (ünnepnap vs. hétköznap eladások összehasonlítása).

A fő KPI-k az összesített árbevétel, profit, rendelésszám, átlagos rendelési érték, valamint a profit/árbevétel arány, melyek régió, kategória és időszak szerint bontva jelennek meg. A reportok PowerBI-ban készülnek, interaktív szűréssel, rendezéssel és lefúrási lehetőségekkel (régió → állam → város). Az adatelemzés/data science rész egy Jupyter notebook-ban valósul meg, amely pandas-alapú feltáró elemzést (EDA), majd LSTM és GRU neurális hálózatokkal történő idősor-előrejelzést tartalmaz a napi értékesítési összeg predikciójára.

## Főbb funkciók

### Választott adatforrások

1. **Superstore Sales Dataset** (Kaggle: [Superstore Dataset Final](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final))
   - ~10 000 sor, CSV formátum
   - Mezők: Order ID, Order Date, Ship Date, Ship Mode, Customer ID, Customer Name, Segment, Country, City, State, Postal Code, Region, Product ID, Category, Sub-Category, Product Name, Sales, Quantity, Discount, Profit
   - Az adatforrás 4 darab CSV fájlra lesz felvágva (~2 500 sor/fájl), így szimulálható az inkrementális betöltés

2. **US Public Holidays** (Kaggle: [US Public Holidays](https://www.kaggle.com/datasets/donnetew/us-holiday-dates-2004-2021) vagy hasonló)
   - USA szövetségi és egyéb ünnepnapok dátumai és megnevezései
   - Dimenzióként szolgál az értékesítési adatok szezonális elemzéséhez (ünnepnapi vs. nem-ünnepnapi eladások)

### Adattárolás megvalósítása

Az adattárolás Microsoft SQL Server-ben (localdb/Express) valósul meg, egy `RetailDW` nevű adatbázisban. A tárolási rétegek:

- **Staging (stage)**: `staging_sales` — nyers, tisztítatlan értékesítési adatok fogadó táblája, ahova az ETL közvetlenül betölti a CSV fájlokat.
- **Dimenzió táblák (dim)**:
  - `dim_holiday` — ünnepnap dátuma, megnevezése, típusa (US Holidays adatforrásból)
  - `dim_category` — termékkategória, alkategória
  - `dim_time` — dátum dimenzió (év, hónap, hét, hét napja)
- **Tény tábla (fact)**: `fact_sales` — tisztított, transzformált értékesítési adatok, idegen kulcsokkal a dimenziókra (csillagséma).
- **Aggregált táblák (agg)**:
  - `agg_monthly_sales` — havi összesítések régió és kategória szerint
  - `agg_category_sales` — kategória/alkategória szintű összesítések

### Megvalósítandó ETL job-ok

| # | Job neve | Leírás | Paraméterek | Transzformáció |
|---|----------|--------|-------------|----------------|
| 1 | **Load Sales Chunk** | Egy CSV részlet betöltése a `staging_sales` táblába | Fájl elérési útvonal (CSV sorszám) | Típuskonverzió, dátum formázás |
| 2 | **Load Holiday Dimension** | US Holidays CSV betöltése a `dim_holiday` táblába | Fájl elérési útvonal | Dátum formázás, ünnepnap típus oszlop kinyerése |
| 3 | **Transform to Fact** | Staging adatok tisztítása és betöltése a `fact_sales` csillagsémába | — | Duplikátum szűrés, dimenzió kulcsok létrehozása (lookup), `dim_time`, `dim_category` és `dim_holiday` feltöltése, ünnepnap flag hozzáadása |
| 4 | **Aggregate Monthly** | Havi összesítés készítése a `fact_sales`-ből | — | GROUP BY év, hónap, régió, kategória; SUM(Sales), SUM(Profit), COUNT(OrderID) |
| 5 | **Aggregate Category** | Kategória összesítés készítése | — | GROUP BY Category, Sub-Category; SUM, AVG aggregációk |

**Ütemezés**: SQL Server Agent segítségével, demo célokra 1 perces ütemezéssel. Az első 4 futás során a 4 CSV részlet sorban betöltődik, majd a transzformációs és aggregációs job-ok lefutnak. Így a PowerBI reportok minden betöltés után frissített adatokat mutatnak.

### Adatok végső helye

A végső, felhasználható adatok a `RetailDW` adatbázis `fact_sales`, `agg_monthly_sales` és `agg_category_sales` tábláiban találhatók, amelyekhez a dimenzió táblák (`dim_holiday`, `dim_category`, `dim_time`) kapcsolódnak csillagséma struktúrában.

### Megjelenítési réteg (PowerBI reportok)

| # | Report neve | Tartalom | Dinamikus funkciók |
|---|-------------|----------|-------------------|
| 1 | **Értékesítési Áttekintés (Dashboard)** | KPI kártyák (össz árbevétel, profit, rendelésszám, átl. rendelési érték), oszlopdiagram kategóriánként | Dátum tartomány szeletelő, szegmens szűrő |
| 2 | **Ünnepnapi Elemzés** | Oszlopdiagram ünnepnapi vs. nem-ünnepnapi eladásokról, top ünnepnapok forgalom szerint | **Lefúrás**: Év → Ünnepnap → Napi bontás, szűrés ünnepnap típusra |
| 3 | **Top Termékek** | Táblázat és oszlopdiagram a legjobb alkategóriákról eladás/profit szerint | Rendezés, keresés, szűrés |
| 4 | **Havi Trendek** | Vonaldiagram havi eladás/profit alakulásáról | Kategória és régió szeletelő, dátum szűrő |

Minden report a SQL Server `RetailDW` adatbázishoz csatlakozik, és az ETL job-ok újrafuttatása után a reportok frissíthetők.

### Data science / adatelemzési funkciók

A data science rész egy Python Jupyter notebook-ban valósul meg:

1. **Feltáró adatelemzés (EDA)**: pandas segítségével az értékesítési adatok eloszlásának, trendjeinek és szezonalitásának vizsgálata. Vizualizáció matplotlib-tel.
2. **Feature extraction**: Ciklikus időbeli jellemzők kódolása szinusz/koszinusz transzformációkkal (hét napja, év napja) — a HF4-ben tanult módszer szerint.
3. **Adatok skálázása**: StandardScaler alkalmazása a bemeneti jellemzőkre és a célváltozóra.
4. **Train/Validation/Test halmaz**: Időalapú felosztás (pl. 2014–2016 tanítás, 2017 validáció, 2018 teszt).
5. **LSTM modell**: Keras Sequential modell LSTM(16) + Dense(1) réteggel, EarlyStopping callback-kel. Célváltozó: napi összesített értékesítés (Sales).
6. **GRU modell**: Ugyanazon architektúra GRU réteggel, összehasonlítás az LSTM-mel.
7. **Vizualizáció**: Tanítási/validációs veszteségfüggvények, valamint tényleges vs. prediktált értékek ábrázolása.

### Egyéb funkciók

Nem tervezett.

## Választott technológiák

| Technológia | Cél |
|-------------|-----|
| **Microsoft SQL Server** (localdb/Express) | Adatbázis — staging, dimenzió, tény és aggregált táblák tárolása (RetailDW) |
| **SQL Server Integration Services (SSIS)** | ETL motor — CSV fájlok betöltése, adattranszformáció, aggregáció. Visual Studio SSIS Projects extension segítségével fejlesztve. |
| **SQL Server Agent** | ETL ütemezés — SSIS csomagok automatikus, időzített futtatása |
| **PowerBI Desktop** | Reporting motor — 4 interaktív report/dashboard készítése szűréssel, rendezéssel, lefúrással |
| **Python 3.x** | Data science szkriptek nyelve |
| **Jupyter Notebook** | Fejlesztési környezet az adatelemzéshez |
| **pandas** | Adatmanipuláció és feltáró elemzés (EDA) |
| **matplotlib** | Adatvizualizáció a notebook-ban |
| **scikit-learn (StandardScaler)** | Adatok skálázása/standardizálása |
| **TensorFlow / Keras** | LSTM és GRU neurális hálózatok építése és tanítása idősor-előrejelzéshez |
| **NumPy** | Numerikus számítások, tömb műveletek |

### Adatfolyam áttekintés

```
CSV fájlok (4x Sales + 1x Holidays)
        │
        ▼
   ┌─────────┐
   │  SSIS   │  ← ETL motor (5 job, SQL Agent ütemezés)
   └────┬────┘
        │
        ▼
 ┌──────────────┐
 │  SQL Server  │  ← RetailDW (staging → dim + fact → agg)
 │  (localdb)   │
 └──┬───────┬───┘
    │       │
    ▼       ▼
 PowerBI  Jupyter Notebook
 (4 report) (EDA + LSTM/GRU előrejelzés)
```
