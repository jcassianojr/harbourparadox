import csv
from pypxlib import Table

# Abre a tabela Paradox (substitua pelo nome correto do seu arquivo)
with Table('clientes.db') as table:
    # Extrai os nomes das colunas da tabela
    fieldnames = list(table.fields.keys())
    
    # Prepara os dados convertendo cada linha em um dicionário padrão do Python
    data = []
    for row in table:
        row_dict = {field: row[field] for field in fieldnames}
        data.append(row_dict)

    # Escreve os dados para um arquivo CSV
    if data:
        with open('resultado.csv', 'w', newline='', encoding='utf-8') as csv_file:
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(data)
            
        print("Conversão concluída com sucesso!")
    else:
        print("A tabela está vazia.")