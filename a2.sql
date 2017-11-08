-- Assignment 2
-- Created by Daniel Yang
-- z3417098

-- QUESTION 1: company names and countries outside Australia
create or replace view Q1(Name, Country) as
select  name, country
from    Company
where   country <> 'Australia'
;

-- QUESTION 2: company codes with at least 6 executive members
create or replace view Q2(Code) as
select  code
from    (select code, count(*) as numExecs -- a subquery that simply counts
         from Executive                    -- the number of records in Executive 
         group by code) as ExecsInCompany  -- table, grouped by code
where   numExecs >= 6
; 

-- QUESTION 3: company names in Technology sector
create or replace view Q3(Name) as
select  c.name
from    company c, category cat
where   cat.code = c.code and cat.sector = 'Technology'
;

-- QUESTION 4: number of industries in each sector
create or replace view Q4(Sector, Number) as
select   sector, count(distinct industry)
from     Category
group by sector
;

-- QUESTION 5: names of executives affiliated with companies in Technology sector
create or replace view Q5(Name) as
select  distinct e.person       -- distinct in case a person appears in more than one Technology company
from    Executive e, Category cat
where   e.code = cat.code and cat.sector = 'Technology'
;

-- QUESTION 6: company names in Services sector that are in Australia and zip code starts with 2
create or replace view Q6(Name) as
select  name
from    Company
where   country = 'Australia' and substr(zip, 1, 1) = '2'     -- extracts first digit of zip
;

-- QUESTION 7: view of ASX table that computes price change and % gain

---- PrevDate function returns the last date from ASX table that is before the given date for a given code
create or replace function PrevDate(_date date, _code char(3)) returns date
as $$
select  max("Date") 
from    ASX
where   code = _code and "Date" < _date
$$ language sql
;

---- Previous price is taken from a self-join on ASX table, with date equal to the date returned by PrevDate function
create or replace view Q7("Date", Code, Volume, PrevPrice, Price, Change, Gain) as
select  a."Date", a.code, a.volume, preva.price, a.price, 
        (a.price - preva.price), (a.price-preva.price)/preva.price * 100
from    ASX a, ASX preva
where   preva."Date" = PrevDate(a."Date", a.code)
        and preva.code = a.code
;

-- QUESTION 8: most active trading stock on a every day, order by date then code

---- MaxVolumeOn function returns the max volume on given date
create or replace function MaxVolumeOn(_date date) returns integer
as $$
select  max(volume)
from    ASX
where   "Date" = _date
$$ language sql
;

create or replace view Q8("Date", Code, Volume) as
select   "Date", code, volume
from     ASX
where    volume = MaxVolumeOn("Date")      -- Take tuple only if volume = max volume on that day
order by "Date", code
;

-- QUESTION 9: number of companies per industry, order by sector then industry
create or replace view Q9(Sector, Industry, Number) as
select   max(cat.sector), cat.industry, count(c.code)   -- Here, max(sector) is just a trick
from     Category cat, Company c                        -- to display a single value for sector
where    c.code = cat.code                              -- (they are all the same for any given industry)
group by cat.industry                                   -- so we can group by industry
order by max(cat.sector), cat.industry
;

-- QUESTION 10: company codes that are only one in their industry

---- Makes use of Q9 view, which has the number of companies in each industry
create or replace view Q10(Code, Industry) as
select  cat.code, cat.industry
from    Category cat, Q9 q
where   cat.industry = q.industry and q."number" = 1
;

-- QUESTION 11: all sectors ranked by their average ratings in desc order

---- Create view to store AvgCompanyRating
create or replace view AvgCompanyRating(code, average) as
select   code, avg(star)
from     Rating
group by code
;

-- Sector average is average of all company averages in sector
create or replace view Q11(Sector, AvgRating) as
select   cat.sector, avg(acr.average)
from     Category cat, AvgCompanyRating acr
where    cat.code = acr.code
group by cat.sector
order by avg(acr.average) desc
;

-- QUESTION 12: executive names that are affiliated with more than one company
create or replace view Q12(Name) as
select  person
from    (select person, count(*) as numCompanies        -- a subquery that simply counts
         from Executive                                 -- the number of records in Executive 
         group by person) as CompaniesForExecs          -- table, grouped by person
where   numCompanies > 1
;

-- QUESTION 13: all companies with address in purely Australian sectors

---- Create view to count number of non-Australian companies in sector (includes those with NULL country)
create or replace view InternationalSectors(Sector, NumNonAustCompanies) as
select   cat.sector, count(*)
from     Category cat, Company c
where    c.code = cat.code and (c.country <> 'Australia' or c.country is NULL)
group by cat.sector
;

create or replace view Q13(Code, Name, Address, Zip, Sector) as
select  c.code, c.name, c.address, c.zip, cat.sector
from    Category cat, Company c
where   c.code = cat.code and not exists (select * from InternationalSectors where sector = cat.sector)
;                         -- there should not be a record in InternationalSectors for purely Australian sectors

-- QUESTION 14: calculate stock gains from first to last day, order by gain desc then code asc

---- Create two functions that receive company code as argument, and return the price on first/last day
create or replace function FirstPrice(_code char(3)) returns numeric
as $$
select  price
from    ASX
where   code = _code and "Date" = (select min("Date")
                                  from ASX
                                  where code = _code)
$$ language sql
;

create or replace function LastPrice(_code char(3)) returns numeric
as $$
select  price
from    ASX
where   code = _code and "Date" = (select max("Date")
                                  from ASX
                                  where code = _code)
$$ language sql
;

create or replace view Q14(Code, BeginPrice, EndPrice, Change, Gain) as
select   code, FirstPrice(code), LastPrice(code), 
         (LastPrice(code) - FirstPrice(code)), (LastPrice(code) - FirstPrice(code))/FirstPrice(code) * 100
from     company
order by (LastPrice(code) - FirstPrice(code))/FirstPrice(code) * 100 desc, code
;

-- QUESTION 15: for all company codes in ASX table, generate min/avg/max price/dailygain

---- Reuses Q7 view for daily gains, but need to add initial price back for comparison since Q7 does not have it
create or replace view Q15(Code, MinPrice, AvgPrice, MaxPrice, MinDayGain, AvgDayGain, MaxDayGain) as
select   code, 
         least(min(price), FirstPrice(code)),                   -- will select first price if first price is smallest
         (sum(price) + FirstPrice(code))/(count(price) + 1),    -- average price with first price included
         greatest(max(price), FirstPrice(code)),                -- will select first price if first price is largest
         min(gain), avg(gain), max(gain)
from     Q7
group by code
;

-- QUESTION 16: trigger to prevent insertion of exec to more than one company
create or replace function CheckOneCompany() returns trigger
as $$
declare
        numOfCompanies integer;
begin
        select count(*) into numOfCompanies 
        from Executive where person = NEW.person;       -- get number of companies that person is already in
        if numOfCompanies > 0 then
                if TG_OP = 'UPDATE' and OLD.person = NEW.person and numOfCompanies = 1 then
                        return NEW;     -- if it is an exec changing companies, but is still only in 1, then allow...
                end if;
                return NULL;    -- otherwise, if exec already has 1 or more record, disallow insert/update
        else
                return NEW;     -- otherwise, allow insert/update
        end if;
end;
$$ language plpgsql
;

create trigger CheckExec
before insert or update on Executive
for each row execute procedure CheckOneCompany();

-- QUESTION 17: trigger to update ratings for highest/worst performing stock to 5/1 on insert to ASX table
create or replace function UpdateRatings() returns trigger
as $$
declare
        maxDailyGainInSector numeric;
        minDailyGainInSector numeric;
        D date;
        S varchar(40);
        r record;
        
begin
        -- D and S are the date and sector of the inserted company 
        D = NEW."Date";
        select sector into S from Category where code = NEW.code;

        -- get value of largest daily gain for that day/sector
        select max(q.gain) into maxDailyGainInSector    
        from Q7 q, Category cat
        where q.code = cat.code and q."Date" = D and cat.sector = S;

        -- get value of lowest daily gain for that day/sector
        select min(q.gain) into minDailyGainInSector    
        from Q7 q, Category cat
        where q.code = cat.code and q."Date" = D and cat.sector = S;

        -- loop through all records for that day/sector whose gain = largest daily gain
        for r in select q.code  
                 from Q7 q, Category cat
                 where q.code = cat.code and q."Date" = D 
                 and cat.sector = S and q.gain = maxDailyGainInSector
        loop
                update Rating   -- and for those codes, update Star in Rating table to 5
                set Star = 5
                where code = r.code;
        end loop;

        -- loop through all records for that day/sector whose gain = lowest daily gain
        for r in select q.code  
                 from Q7 q, Category cat
                 where q.code = cat.code and q."Date" = D 
                 and cat.sector = S and q.gain = minDailyGainInSector
        loop
                update Rating   -- and for those codes, update Star in Rating table to 1
                set Star = 1
                where code = r.code;
        end loop;
        return NULL;    -- the return value of any after trigger is irrelevant
end;
$$ language plpgsql
;

create trigger InsertToASX
after insert on ASX
for each row execute procedure UpdateRatings();

-- QUESTION 18: trigger to log any updates to ASX table
create or replace function LogUpdates() returns trigger
as $$
begin     
        insert into ASXLog values (      
        now(), OLD."Date", OLD.code, OLD.volume, OLD.price      -- now() is the timestamp for the update
        );                                                      -- we want to record the OLD values of ASX record 
        return NULL;                                            -- the return of any after trigger is irrelevant
end;
$$ language plpgsql
;

create trigger UpdateToASX
after update on ASX
for each row execute procedure LogUpdates();