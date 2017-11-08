-- COMP9311 17s2 Assignment 1
-- Schema for OzCars
--
-- Date: 25/08/17
-- Student Name: Daniel Yang
-- Student ID: z3417098

-- EMPLOYEE

create table Employee (
	EID		serial, 
        firstName	varchar(50) not null,	
	lastName	varchar(50) not null,
    	salary       	integer not null check (salary > 0),
	TFN		char(9) unique not null check (TFN ~ '\d{9}'),
	primary key (EID)
);

create table Admin (
	EID		integer,
	primary key (EID),
	foreign key (EID) references Employee(EID)
);

create table Mechanic (
	EID		integer,
	license		char(8) unique not null check (license ~ '[0-9A-Za-z]{8}'),
	primary key (EID),
	foreign key (EID) references Employee(EID)
);

create table Salesman (
	EID		integer,
	commRate	integer not null check (commRate between 5 and 20),
	primary key (EID),
	foreign key (EID) references Employee(EID)
);

-- CLIENT

create domain URLType as
	varchar(100) check (value like 'http://%');

create domain EmailType as
	varchar(100) check (value like '%@%.%');

create domain PhoneType as
	char(10) check (value ~ '\d{10}');

create table Client (
	CID          	serial,
	name		varchar(100) not null,
	address		varchar(200) not null,
	phone		PhoneType not null,
	email		EmailType unique,
	primary key (CID)
);

create table Company (
	CID		integer,
	ABN		char(11) unique not null check (ABN ~ '\d{11}'),
	url		URLType unique,
	primary key (CID), 
	foreign key (CID) references Client(CID)
);	

-- CAR

create domain CarLicenseType as
        varchar(6) check (value ~ '[0-9A-Za-z]{1,6}');

create domain OptionType as varchar(12)
	check (value in ('sunroof','moonroof','GPS','alloy wheels','leather'));

create domain VINType as char(17) check (value ~ '[0-9A-Z]{17}' and value ~ '[^OIQ]{17}');

create table Car (
	VIN		VINType,
	year		integer not null check (year between 1970 and 2099),
	model		varchar(40) not null,
	manufacturer	varchar(40) not null,
	primary key (VIN)
);

create table CarOptions (
	VIN		VINType,
	options		OptionType not null,
	primary key (VIN,options),
	foreign key (VIN) references Car(VIN)
);

create table NewCar (
	VIN		VINType,
	cost		numeric(8,2) not null check (cost > 0),
	charges		numeric(8,2) not null check (charges > 0),
	primary key (VIN),
	foreign key (VIN) references Car(VIN)
);

create table UsedCar (
	VIN		VINType,
	plateNumber	CarLicenseType unique not null,
	primary key (VIN),
	foreign key (VIN) references Car(VIN)
);


-- REPAIRS

create table RepairJob (
	VIN		VINType,
	"number"	integer check (number between 1 and 999),
	description	varchar(250) not null,
	parts		numeric(8,2) not null check (parts > 0),
	work		numeric(8,2) not null check (work > 0),
	"date"		date not null,
	paidBy		integer not null,
	primary key (VIN,"number"),
	foreign key (VIN) references Car(VIN),
	foreign key (paidBy) references Client(CID)
);

create table Does (
	mechanic	integer,
	VIN		VINType,
	"number"	integer,
	primary key (mechanic,VIN,"number"),
	foreign key (mechanic) references Mechanic(EID),
	foreign key (VIN,"number") references RepairJob(VIN,"number")
);

-- SALES

create table Sells (
	buyer		integer,
	salesman	integer not null,
	usedCar		VINType,
	"date"		date,
	price		numeric(8,2) not null check (price > 0),
	commission	numeric(8,2) not null check (commission > 0),
	primary key (buyer,usedCar,"date"),
	foreign key (buyer) references Client(CID),
	foreign key (salesman) references Salesman(EID),
	foreign key (usedCar) references UsedCar(VIN)
);

create table Buys (
	seller		integer,
	salesman	integer not null,
	usedCar		VINType,
	"date"		date,
	price		numeric(8,2) not null check (price > 0),
	commission	numeric(8,2) not null check (commission > 0),
	primary key (seller,usedCar,"date"),
	foreign key (seller) references Client(CID),
	foreign key (salesman) references Salesman(EID),
	foreign key (usedCar) references UsedCar(VIN)
);

create table SellsNew (
	buyer		integer,
	salesman	integer not null,
	newCar		VINType,
	"date"		date not null,
	price		numeric(8,2) not null check (price > 0),
	commission	numeric(8,2) not null check (commission > 0),
	plateNumber	CarLicenseType not null,
	primary key (buyer,newCar),
	foreign key (buyer) references Client(CID),
	foreign key (salesman) references Salesman(EID),
	foreign key (newCar) references NewCar(VIN)
);