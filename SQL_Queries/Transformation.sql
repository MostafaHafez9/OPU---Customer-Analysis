--============================
-- OPU Project (Transformation)
--============================


--Create a cleaned table

if OBJECT_ID('cleaned_online_retail','u') is not null
	drop table cleaned_online_retail;

	create table cleaned_online_retail(
		invoice int,
		stock_code nvarchar(50),
		description nvarchar(100),
		quantity int,
		invoice_date datetime2,
		price decimal(18,2),
		customer_id int,
		country nvarchar(50)
		)



-- The transformation query

with filtered as (
	select
		Invoice,
		StockCode,
		Description,
		Quantity,
		InvoiceDate,
		Price,
		Customer_ID,
		trim(country) country
	from online_retail
	where invoice not like 'c%' and
		  Customer_ID is not null and
		  Quantity > 0 and Quantity < 50 and
		  price > 0 and country != 'Isreal'
	)

, remove_duplicates as (
	select
		*
	from (select 
				*,
				ROW_NUMBER() over(partition by invoice, stockcode, description,quantity, invoicedate, price, customer_id,country
									order by invoice) flag
		  from filtered)t
	where flag = 1)

insert into cleaned_online_retail (invoice, stock_code,description,quantity,invoice_date,price,customer_id,country)

select
	Invoice,
	StockCode,
	Description,
	Quantity,
	InvoiceDate,
	Price,
	Customer_ID,
	country
from remove_duplicates;



--Check the cleaned table

select * from cleaned_online_retail;
