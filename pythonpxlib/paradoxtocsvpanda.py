from pypxlib import Table 
import pandas as pd
table = Table('siglas.db')
table.fields
len(table)
data = [row.as_dict() for row in table] 
df = pd.DataFrame(data)
df.to_csv('resultado.csv', index=False)