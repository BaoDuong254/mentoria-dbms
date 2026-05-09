import csv
from datetime import datetime

input_file = 'bank_transactions.csv'
output_file = 'bank_transactions_clean.csv'

def format_date(date_str):
    date_str = date_str.strip()
    if not date_str:
        return ''
    
    # Danh sách các định dạng đầu vào có thể gặp
    # Thêm '%Y-%m-%d' để đọc được các dòng có dấu gạch ngang
    input_formats = ('%d/%m/%y', '%d/%m/%Y', '%Y-%m-%d', '%d-%m-%Y')
    
    for fmt in input_formats:
        try:
            dt = datetime.strptime(date_str, fmt)
            
            # Xử lý logic năm sinh (nếu là năm có 2 chữ số)
            if dt.year > 2026: # Cập nhật mốc thời gian hiện tại
                dt = dt.replace(year=dt.year - 100)
                
            # Trả về định dạng YYYY/MM/DD với dấu gạch chéo theo ý bạn
            return dt.strftime('%Y-%m-%d')
        except ValueError:
            continue
            
    # Nếu không khớp định dạng nào, giữ nguyên để không mất dữ liệu
    return date_str

print("Starting data processing...")
with open(input_file, mode='r', encoding='utf-8-sig') as infile, \
     open(output_file, mode='w', newline='', encoding='utf-8') as outfile:
    
    reader = csv.reader(infile)
    writer = csv.writer(outfile)
    
    # Xử lý Header: Đổi 'TransactionAmount (INR)' thành 'TransactionAmount'
    headers = next(reader)
    headers[8] = 'TransactionAmount'
    writer.writerow(headers)
    
    count = 0
    for row in reader:
        if len(row) < 9: continue # Bỏ qua các dòng bị lỗi thiếu cột
        
        row[2] = format_date(row[2]) # Sửa CustomerDOB
        row[6] = format_date(row[6]) # Sửa TransactionDate
        
        # Điền 0 nếu AccountBalance hoặc Amount bị trống
        row[5] = row[5] if row[5].strip() else '0'
        row[8] = row[8] if row[8].strip() else '0'
        
        writer.writerow(row)
        count += 1
        
print(f"Done! Processed {count} rows and saved to {output_file}")