create database pixar_film_db;
use pixar_film_db;

SET SQL_SAFE_UPDATEs = 0;

update pixarfilms
set ReleaseDate = str_to_date(ReleaseDate, "%d-%m-%Y");

select * from academy;
select * from boxoffice;
select * from genres;
select * from pixarfilms;
select * from pixarpeople;
select * from publicresponse;
select film, worldwide_collection, net_profit from net_profit;


# Project Problems :

create view worldwide_gross as 
							   select film, budget, 
							   (boxofficeuscanada + boxofficeother) worldwide_collection
					           from boxoffice;



create view net_profit as 
						 select film, budget, worldwide_collection, 
								(worldwide_collection - budget) as net_profit
						 from worldwide_gross;

select * from net_profit;      

/*
Objective :
Evaluate Pixar films by combining net profit and IMDb ratings to 
classify each as a 'Blockbuster', 'Commercial Success', or 'Underperformer'
based on financial return and audience approval.

Classification Criteria :
- 'Blockbuster': Net profit exceeds twice the budget and IMDb rating is above the average.
- 'Commercial Success': Net profit meets or exceeds budget and IMDb rating is at least average.
- 'Underperformer': Net profit is below budget OR IMDb rating is below average.
*/


with rating_data as (
					 select 
					 film, 
					 imdbscore as imdb_rating, 
					 round(avg(imdbscore) over (), 1) as avg_imdb_rating
					 from publicresponse
					),

classified_films as (
					 select  
					 f.film,  
					 year(f.releasedate) as release_year,
				     w.budget,  
					 n.net_profit,  
					 r.imdb_rating,  
					 r.avg_imdb_rating,
					 case
						when n.net_profit > 2 * w.budget and r.imdb_rating > r.avg_imdb_rating then 'Blockbuster'
						when n.net_profit >= w.budget and r.imdb_rating >= r.avg_imdb_rating then 'Commercial Success'
						else 'Underperformer'
					end as profitability_status
					from worldwide_gross w
					join pixarfilms f on w.film = f.film
					join net_profit n on w.film = n.film
					join rating_data r on w.film = r.film
				   )

select 
    profitability_status,
    count(*) as count
from classified_films
group by profitability_status;

/* Objective :
   Which films have performed best at net_profit? Did they have the highest budgets?
*/

with budget_ranked as (
    select film, budget, worldwide_collection, net_profit,
           dense_rank() over(order by net_profit desc) as net_profit_rank,
           dense_rank() over(order by budget desc) as budget_rank
    from net_profit
)

select film, budget, net_profit, 
	   net_profit_rank, budget_rank,
       case
		   when net_profit_rank = 1 and budget_rank = 1 then 'Top performer and highest budget'
           when budget_rank = 1 then 'Highest budget, yet underperformed'
           else 'Average success'
       end as highlight
from budget_ranked
order by net_profit_rank;


/* Objective :
   Which films received the most awards? Are they also the best rated?
*/

with most_received_awards as (
							  select film, count(*) as total_awards_won
							  from academy
							  where status = 'won'
							  group by film
							 ),
best_rated as (
			   select *,
						case
						   when CinemaScore = 'A+' then 100
						   when CinemaScore = 'A'  then 95
						   when CinemaScore = 'A-' then 90
						   else null
						end as CinemaScore_Value
				from publicresponse
			  )

select m.film, m.total_awards_won, 

       round( 
           (b.rottentomatoesscore * 0.3) + 
           (b.metacriticscore * 0.2) + 
           (b.imdbscore * 10 * 0.3) + 
           (b.CinemaScore_Value * 0.2),
           0) as Overall_Score
from most_received_awards m
join best_rated b
on m.film = b.film
order by m.total_awards_won desc;

/* Objective : 
   Which Pixar directors have consistently received the highest critical acclaim, 
   and how many films have they directed?
*/

select pp.name as director_name, 
	   count(distinct pp.film) as total_films_directed,
	   round(avg(pr.metacriticscore),2) as  avg_critic_score,
	   dense_rank() over(order by avg(pr.metacriticscore) desc) as acclaim_director_rank
from pixarpeople pp
inner join publicresponse pr
on pp.film = pr.film
where pp.roletype = 'director' and pr.metacriticscore is not null
group by director_name;


/*Objective: 
Trend Analysis*/

with yearly_gross as(
					 select f.film,
							year(f.releasedate) AS release_year,
							w.worldwide_collection as worldwide_collection
					 from pixarfilms f
					 join worldwide_gross w 
                     on f.film = w.film
					 where w.worldwide_collection is not null
					),
                    
	 ranked_films as(
					 select *,
						    rank() over (partition by release_year order by worldwide_collection desc) as yearly_rank
					 from yearly_gross
					)
select release_year, worldwide_collection, film
from ranked_films
where yearly_rank = 1
order by release_year;


