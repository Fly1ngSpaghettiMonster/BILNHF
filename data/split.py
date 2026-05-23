import pandas as pd

df = pd.read_csv('raw/Sample - Superstore.csv', encoding='latin-1')
print(f"Total rows: {len(df)}")

chunk_size = len(df) // 4
for i in range(4):
    start = i * chunk_size
    end = (i+1) * chunk_size if i < 3 else len(df)
    chunk = df.iloc[start:end]
    chunk.to_csv(f'split/sales_chunk_{i+1}.csv', index=False)
    print(f"Chunk {i+1}: rows {start}-{end-1} ({len(chunk)} rows)")