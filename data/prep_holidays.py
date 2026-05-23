import pandas as pd

df = pd.read_csv('raw/US Holiday Dates (2004-2021).csv')

# Remove commas from holiday names to make BULK INSERT compatible
df['Holiday'] = df['Holiday'].str.replace(',', '', regex=False)

# Save clean version (pipe-delimited to avoid any comma issues)
df.to_csv('holidays/us_holidays_clean.csv', index=False, sep='|')
print(f"Holidays cleaned: {len(df)} rows")
print(df.head())
