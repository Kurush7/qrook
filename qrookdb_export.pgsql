--
-- PostgreSQL database dump
--

-- Dumped from database version 13.2 (Debian 13.2-1.pgdg100+1)
-- Dumped by pg_dump version 13.1 (Debian 13.1-1.pgdg100+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: qrook; Type: SCHEMA; Schema: -; Owner: admin
--

CREATE SCHEMA qrook;


ALTER SCHEMA qrook OWNER TO admin;

--
-- Name: plpython3u; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpython3u WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpython3u; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpython3u IS 'PL/Python3U untrusted procedural language';


--
-- Name: author_minimal; Type: TYPE; Schema: public; Owner: kurush
--

CREATE TYPE public.author_minimal AS (
	id integer,
	name character varying(256)
);


ALTER TYPE public.author_minimal OWNER TO kurush;

--
-- Name: author_preview; Type: TYPE; Schema: public; Owner: kurush
--

CREATE TYPE public.author_preview AS (
	id integer,
	name character varying(256),
	photo character varying
);


ALTER TYPE public.author_preview OWNER TO kurush;

--
-- Name: book_preview; Type: TYPE; Schema: public; Owner: kurush
--

CREATE TYPE public.book_preview AS (
	id integer,
	title character varying(256),
	authors public.author_minimal[],
	skin_image character varying
);


ALTER TYPE public.book_preview OWNER TO kurush;

--
-- Name: series_preview; Type: TYPE; Schema: public; Owner: kurush
--

CREATE TYPE public.series_preview AS (
	id smallint,
	title character varying(256),
	skin_image character varying,
	books_count integer,
	authors public.author_minimal[]
);


ALTER TYPE public.series_preview OWNER TO kurush;

--
-- Name: get_author_preview(integer); Type: FUNCTION; Schema: public; Owner: kurush
--

CREATE FUNCTION public.get_author_preview(author_id_param integer) RETURNS public.author_preview
    LANGUAGE plpython3u
    AS $$
authors = plpy.execute(''' select id, name, photo from authors where id = %d''' % author_id_param)
if len(authors) == 0: return None
return authors[0]
$$;


ALTER FUNCTION public.get_author_preview(author_id_param integer) OWNER TO kurush;

--
-- Name: get_book_authors(integer); Type: FUNCTION; Schema: public; Owner: kurush
--

CREATE FUNCTION public.get_book_authors(book_id_param integer) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY SELECT a.id AS id, a.name as name
                 FROM books b
                          JOIN books_authors ba ON b.id = ba.book_id
                          JOIN authors a ON a.id = ba.author_id
                 WHERE b.id = book_id_param;
END;
$$;


ALTER FUNCTION public.get_book_authors(book_id_param integer) OWNER TO kurush;

--
-- Name: get_book_preview(integer); Type: FUNCTION; Schema: public; Owner: kurush
--

CREATE FUNCTION public.get_book_preview(book_id_param integer) RETURNS public.book_preview
    LANGUAGE plpython3u
    AS $$
books = plpy.execute(''' select id, title, skin_image from books where id = %d''' % book_id_param)
if len(books) == 0: return None

authors = list(plpy.execute('''select * from get_book_authors(%d) as f(id int, name varchar);''' % book_id_param))
return {
    'id': books[0]['id'],
    'title': books[0]['title'],
    'skin_image': books[0]['skin_image'],
    'authors': authors
}
$$;


ALTER FUNCTION public.get_book_preview(book_id_param integer) OWNER TO kurush;

--
-- Name: get_books_authors(integer[]); Type: FUNCTION; Schema: public; Owner: kurush
--

CREATE FUNCTION public.get_books_authors(book_ids_param integer[]) RETURNS SETOF record
    LANGUAGE plpython3u
    AS $$
str_params = ', '.join([str(x) for x in book_ids_param])
query = '''SELECT distinct b.id as book_id, a.id AS author_id, a.name as author_name
         FROM books b
                  JOIN books_authors ba ON b.id = ba.book_id
                  JOIN authors a ON a.id = ba.author_id
         WHERE b.id in (%s)''' % str_params
a_ids = list(plpy.execute(query))
return a_ids
$$;


ALTER FUNCTION public.get_books_authors(book_ids_param integer[]) OWNER TO kurush;

--
-- Name: get_series_authors(integer[]); Type: FUNCTION; Schema: public; Owner: kurush
--

CREATE FUNCTION public.get_series_authors(series_ids_param integer[]) RETURNS SETOF record
    LANGUAGE plpython3u
    AS $$
str_params = ', '.join([str(x) for x in series_ids_param])
query = '''select distinct s.id as series_id, a.id as author_id, a.name as author_name, count(*) as books_count
            from series s
            join books_series on books_series.series_id = s.id
            join books_authors ba on books_series.book_id = ba.book_id
            join authors a on a.id = ba.author_id
            WHERE s.id in (%s) group by s.id, a.id, a.name''' % str_params
a_data = list(plpy.execute(query))
return a_data
$$;


ALTER FUNCTION public.get_series_authors(series_ids_param integer[]) OWNER TO kurush;

--
-- Name: get_series_preview(integer); Type: FUNCTION; Schema: public; Owner: kurush
--

CREATE FUNCTION public.get_series_preview(series_id_param integer) RETURNS public.series_preview
    LANGUAGE plpython3u
    AS $$
series = plpy.execute(''' select s.id, s.title, s.skin_image from series s where id = %d''' % series_id_param)
if len(series) == 0:
    return None

result = {
    'id': series[0]['id'],
    'title': series[0]['title'],
    'skin_image': series[0]['skin_image'],
}

data = plpy.execute(''' SELECT bs.book_id as id
                            from books_series bs
                            join series s on bs.series_id = s.id
                            where series_id = %d''' % series_id_param)
count = len(data)
result['books_count'] = count
if count == 0:
    return result

book_id = data[0]['id']
authors = list(plpy.execute('''select * from get_book_authors(%d) as f(id int, name varchar);''' % book_id))
result['authors'] = authors

return result
$$;


ALTER FUNCTION public.get_series_preview(series_id_param integer) OWNER TO kurush;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: authors; Type: TABLE; Schema: public; Owner: kurush
--

CREATE TABLE public.authors (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    name character varying(256) NOT NULL,
    birthdate date,
    country character varying(64),
    photo character varying,
    description character varying
);


ALTER TABLE public.authors OWNER TO kurush;

--
-- Name: authors_id_seq; Type: SEQUENCE; Schema: public; Owner: kurush
--

ALTER TABLE public.authors ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.authors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: book_files; Type: TABLE; Schema: public; Owner: kurush
--

CREATE TABLE public.book_files (
    publication_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    file_path character varying(256) NOT NULL,
    file_type character varying(16)
);


ALTER TABLE public.book_files OWNER TO kurush;

--
-- Name: books; Type: TABLE; Schema: public; Owner: kurush
--

CREATE TABLE public.books (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    title character varying(256) NOT NULL,
    skin_image character varying,
    description character varying,
    genres character varying[]
);


ALTER TABLE public.books OWNER TO kurush;

--
-- Name: books_authors; Type: TABLE; Schema: public; Owner: kurush
--

CREATE TABLE public.books_authors (
    author_id integer,
    book_id integer
);


ALTER TABLE public.books_authors OWNER TO kurush;

--
-- Name: books_id_seq; Type: SEQUENCE; Schema: public; Owner: kurush
--

ALTER TABLE public.books ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.books_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: books_series; Type: TABLE; Schema: public; Owner: kurush
--

CREATE TABLE public.books_series (
    series_id integer,
    book_id integer,
    book_number smallint
);


ALTER TABLE public.books_series OWNER TO kurush;

--
-- Name: publications; Type: TABLE; Schema: public; Owner: kurush
--

CREATE TABLE public.publications (
    id integer NOT NULL,
    book_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    publication_year smallint,
    language_code character varying(2),
    isbn bigint,
    isbn13 bigint,
    info jsonb DEFAULT '{}'::jsonb
);


ALTER TABLE public.publications OWNER TO kurush;

--
-- Name: publications_id_seq; Type: SEQUENCE; Schema: public; Owner: kurush
--

ALTER TABLE public.publications ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: series; Type: TABLE; Schema: public; Owner: kurush
--

CREATE TABLE public.series (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    title character varying(256) NOT NULL,
    is_finished boolean,
    books_count smallint DEFAULT 0,
    skin_image character varying,
    description character varying
);


ALTER TABLE public.series OWNER TO kurush;

--
-- Name: series_id_seq; Type: SEQUENCE; Schema: public; Owner: kurush
--

ALTER TABLE public.series ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.series_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: kurush
--

CREATE TABLE public.users (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    name character varying(256),
    surname character varying(256),
    email character varying(64),
    login character varying(64),
    password character varying(64),
    avatar character varying
);


ALTER TABLE public.users OWNER TO kurush;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: kurush
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO kurush;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kurush
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: authors; Type: TABLE DATA; Schema: public; Owner: kurush
--

COPY public.authors (id, created_at, updated_at, name, birthdate, country, photo, description) FROM stdin;
2	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Фрай Макс	\N	\N	\N	Макс Фрай — литературный псевдоним сначала двух писателей, Светланы Мартынчик и Игоря Стёпина, впоследствии Светлана Мартынчик писала самостоятельно[1]. 
11	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Марион Айзек	\N	\N	\N	«Тепло наших тел» (англ. Warm Bodies) — роман, написанный американским блогером Айзеком Марионом, по которому в 2013 году вышел одноимённый фильм режиссёра Джонатана Ливайна.\n
16	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Пехов Алексей	\N	Россия	\N	\N
40	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	ЧеширКо	\N	\N	\N	\N
47	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Гомер	\N	\N	\N	\N
52	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Атеев Алексей	\N	\N	\N	\N
124	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Солнцева Наталья	\N	\N	\N	\N
41	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Абгарян Наринэ	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/0/0b/Narine_Abgaryan_04.jpg/220px-Narine_Abgaryan_04.jpg	Наринэ Юрьевна Абгарян (арм. Նարինե Յուրիի Աբգարյան; род. 14 января 1971, г. Берд, Тавуш, Армения) — армянская русскоязычная писательница[1], блогер. Лауреат премии "Ясная Поляна" (2016) и номинант "Большой книги" (2011). Автор бестселлеров «Манюня» и «Люди, которые всегда со мной»[2]. В 2020 году The Guardian называет её в числе самых ярких авторов Европы[3].\n
42	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Экслер Алекс	1966-02-28	Россия	http://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/Mobile_World_Congress_2010_by_Alexander_Plyushchev_-_IMG_1436.jpg/200px-Mobile_World_Congress_2010_by_Alexander_Plyushchev_-_IMG_1436.jpg	\N
45	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Задорнов Михаил	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Mikhail_Zadornov_on_stage%2C_2007_%28cropped%29.jpg/232px-Mikhail_Zadornov_on_stage%2C_2007_%28cropped%29.jpg	\N
49	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Стайн Роберт	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/6/68/R_l_stine_2008.jpg/274px-R_l_stine_2008.jpg	\N
54	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Кунц Дин	\N	США	\N	\N
56	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Мартьянов Андрей	\N	\N	\N	Андрей Леонидович Мартьянов (род. 3 сентября 1973, Ленинград) — русский писатель, блогер, переводчик фантастических и исторических произведений. Основные жанры — исторические романы, фэнтези, фантастика.\n
68	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Линн Виссон	\N	\N	\N	\N
73	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Булгаков	\N	\N	\N	\N
70	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Сервантес Мигель	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/0/09/Cervantes_J%C3%A1uregui.jpg/274px-Cervantes_J%C3%A1uregui.jpg	\N
72	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Голсуорси Джон	1867-04-14	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/John_Galsworthy_2.jpg/274px-John_Galsworthy_2.jpg	\N
103	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Мопассан	\N	\N	\N	\N
113	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Грэхем Линн	\N	\N	\N	Эйми Линн Грэм (англ. Aimee Lynn Graham, МФА: [ˈeɪ̯mi ˈlɪn ˈgræm]; родилась 20 сентября 1971 (1971-09-20)) — американская актриса и младшая сестра актрисы Хизер Грэм.\n
114	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Макнот Джудит	\N	США	\N	Джудит Макнот (англ. Judith McNaught; родилась 10 мая 1944) — американская писательница, автор 17 любовных романов. Именно Макнот является основоположником жанра исторического любовного романа эпохи Регентства[1].\n
117	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Голден Артур	\N	США	\N	А́ртур Го́лден (англ. Arthur Golden; 6 декабря 1956 года, Чаттануга, Теннесси, США) — американский японист и писатель. Автор романа-бестселлера «Мемуары гейши», опубликованного в 1997 году. Его книга была продана тиражом более 4 миллионов экземпляров и переведена более чем на 30 языков.\n
119	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Деверо Джуд	\N	\N	\N	\N
123	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Михалкова Елена	\N	\N	\N	А́нна Ники́тична Михалко́ва (род. 14 мая 1974, Москва, РСФСР, СССР) — советская и российская киноактриса, кинопродюсер, телеведущая; заслуженная артистка Российской Федерации (2019)[2]. Член Общероссийской общественной организации «Союз кинематографистов Российской Федерации» (г. Москва)[2].\n
131	2021-03-03 20:40:25.690852+00	2021-03-03 20:40:25.690852+00	Делакорт Шона	\N	\N	\N	\N
132	2021-03-03 20:40:47.690656+00	2021-03-03 20:40:47.690656+00	Меттоуз Дженнифер	\N	\N	\N	\N
1	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Прачетт Терри	1948-02-28	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/10.12.12TerryPratchettByLuigiNovi1.jpg/250px-10.12.12TerryPratchettByLuigiNovi1.jpg	\N
3	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Ле Гуин Урсула	1929-02-21	США	http://upload.wikimedia.org/wikipedia/commons/thumb/1/16/Ursula_Le_Guin_%283551195631%29_b_%28cropped%29.jpg/274px-Ursula_Le_Guin_%283551195631%29_b_%28cropped%29.jpg	Ле Гуин — автор романов, стихов, детских книг, публицист. Наибольшую известность получила как автор романов и повестей в жанрах научной фантастики и фэнтези. Книги Ле Гуин отмечены интересом к межкультурному взаимодействию и конфликтам, даосизму, анархизму и коммунизму, феминизму, психологическим и социальным темам. Она являлась одним из наиболее авторитетных фантастов, обладательницей нескольких высших наград в области научной фантастики и фэнтези («Хьюго», «Небьюла», «Локус»).\n
4	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Мартин Джордж	1948-02-20	США	http://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/George_R._R._Martin_SDCC_2014.jpg/260px-George_R._R._Martin_SDCC_2014.jpg	Джордж Ре́ймонд Ри́чард Ма́ртин (англ. George Raymond Richard Martin, род. 20 сентября 1948) — современный американский писатель-фантаст, сценарист, продюсер и редактор, лауреат многих литературных премий. В 1970—1980-е годы получил известность благодаря рассказам и повестям в жанре научной фантастики, литературы ужасов и фэнтези. Наибольшую славу ему принес выходящий с 1996 года фэнтезийный цикл «Песнь Льда и Огня», позднее экранизированный компанией HBO в виде популярного телесериала «Игра престолов». Эти книги дали основания литературным критикам называть Мартина «американским Толкином»[5]. В 2011 году журнал Time включил Джорджа Мартина в свой список самых влиятельных людей в мире[6].\n
100	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Лоренс Ким	1990-04-15	США	http://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Jennifer_Lawrence_in_2018.png/225px-Jennifer_Lawrence_in_2018.png	\N
5	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Леви Марк	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/8/8d/Marc_levy.jpg/274px-Marc_levy.jpg	Марк Леви́ (фр. Marc Levy; род. 16 октября 1961 года) — французский писатель-романист, автор романа «Только если это было правдой», по мотивам которого в 2005 году был снят фильм «Между небом и землёй».\n
6	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Лемони Сникет	\N	\N	http://upload.wikimedia.org/wikipedia/ru/thumb/4/4a/%D0%9F%D0%BE%D1%81%D1%82%D0%B5%D1%80_%D1%84%D0%B8%D0%BB%D1%8C%D0%BC%D0%B0_%D0%9B%D0%B5%D0%BC%D0%BE%D0%BD%D0%B8_%D0%A1%D0%BD%D0%B8%D0%BA%D0%B5%D1%82-_33_%D0%BD%D0%B5%D1%81%D1%87%D0%B0%D1%81%D1%82%D1%8C%D1%8F.jpg/212px-%D0%9F%D0%BE%D1%81%D1%82%D0%B5%D1%80_%D1%84%D0%B8%D0%BB%D1%8C%D0%BC%D0%B0_%D0%9B%D0%B5%D0%BC%D0%BE%D0%BD%D0%B8_%D0%A1%D0%BD%D0%B8%D0%BA%D0%B5%D1%82-_33_%D0%BD%D0%B5%D1%81%D1%87%D0%B0%D1%81%D1%82%D1%8C%D1%8F.jpg	«Лемони Сникет: 33 несчастья» (англ. Lemony Snicket’s A Series of Unfortunate Events) — американский фильм-сказка 2004 года, экранизация книжной серии «33 несчастья», написанных Дэниелом Хэндлером. В основу сценария легли события первых трёх книг — «Скверное начало», «Змеиный зал» и «Огромное окно». Режиссёр картины — Брэд Силберлинг, а главную роль графа Олафа сыграл Джим Керри. В ролях второго плана снялись Билли Конноли, Тимоти Сполл и Мерил Стрип. Роль Лемони Сникета озвучил Джуд Лоу, а Кетрин О’Хара, Дастин Хоффман, Дэниэел Хэндлер, Хелена Бонэм Картер появились в ролях-камео.\n
7	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Джеффри Форд	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/e/e1/Jeffrey_Ford.jpg/200px-Jeffrey_Ford.jpg	Джеффри Форд (англ. Jeffrey Ford) — американский писатель, пишущий в жанрах фантастики, НФ, фэнтези, мистика.\n
8	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Семёнова Мария	\N	СССР	http://upload.wikimedia.org/wikipedia/commons/thumb/d/db/Maria_Semenova_%28writer%29_09-2011.jpg/250px-Maria_Semenova_%28writer%29_09-2011.jpg	Мари́я Васи́льевна Семёнова (род. 1 ноября 1958, Ленинград) — русская писательница, литературный переводчик. Наиболее известна как автор серии книг «Волкодав»[2]. Автор многих исторических произведений, в частности исторической энциклопедии «Мы — славяне!»[3]. Одна из основателей поджанра фантастической литературы «славянского фэнтези»[4]. Также автор детективных романов.\n
9	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Майер Стефани	1973-02-24	США	http://upload.wikimedia.org/wikipedia/commons/thumb/6/63/Stephenie_Meyer_by_Gage_Skidmore.jpg/274px-Stephenie_Meyer_by_Gage_Skidmore.jpg	Сте́фани Мо́рган Ма́йер (англ. Stephenie Morgan Meyer; 24 декабря 1973, Хартфорд, США) — американская писательница, получившая известность благодаря серии романов «Сумерки». Во всем мире количество проданных книг серии «Сумерки» — 85 миллионов экземпляров, переведённых на 37 языков, включая русский[5].\n
23	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Джордан Роберт	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Robert_Jordan.jpg/266px-Robert_Jordan.jpg	Роберт Джордан (англ. Robert Jordan; 17 октября 1948 — 16 сентября 2007) — псевдоним американского писателя; настоящее имя — Джеймс Оливер Ригни-младший (англ. James Oliver Rigney, Jr.). Получил широкую известность как автор цикла «Колесо Времени». Писал также под именами Реган О’Нил (англ. Regan O’Neal) и Джексон О’Рейли (англ. Jackson O’Reilly).\n
10	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Ролинг Джоан	\N	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/5/5d/J._K._Rowling_2010.jpg/274px-J._K._Rowling_2010.jpg	Джоан Роулинг (англ. Joanne Rowling; род. 31 июля 1965[7]), известная под псевдонимами Дж. К. Роулинг (J. K. Rowling)[8], Джоан Кэтлин Роулинг (англ. Joanne Kathleen Rowling) и Роберт Гелбрейт (Robert Galbraith), — британская писательница, сценаристка и кинопродюсер, наиболее известная как автор серии романов о Гарри Поттере. Книги о Гарри Поттере получили несколько наград и были проданы в количестве более 500 миллионов экземпляров[9]. Они стали самой продаваемой серией книг в истории[10] и основой для серии фильмов, ставшей третьей по кассовому сбору серией фильмов в истории[11]. Джоан Роулинг сама утверждала сценарии фильмов[12], а также вошла в состав продюсеров последних двух частей[13].\n
12	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Панов Вадим	\N	Россия	http://upload.wikimedia.org/wikipedia/commons/thumb/7/71/%D0%92%D0%B0%D0%B4%D0%B8%D0%BC_%D0%9F%D0%B0%D0%BD%D0%BE%D0%B2.jpg/274px-%D0%92%D0%B0%D0%B4%D0%B8%D0%BC_%D0%9F%D0%B0%D0%BD%D0%BE%D0%B2.jpg	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n
13	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Бьёрн Анастасия	\N	\N	http://upload.wikimedia.org/wikipedia/ru/thumb/4/4b/Chess_musical.jpg/274px-Chess_musical.jpg	«Ша́хматы» (англ. «Chess») — мюзикл, созданный в 1984 году. Музыка была написана бывшими членами шведской поп-группы ABBA Бьорном Ульвеусом и Бенни Андерссоном, автором текста стал Тим Райс, создавший такие мюзиклы, как Иисус Христос — суперзвезда, Эвита и Король Лев. В 2006 году «Шахматы» заняли седьмую строчку чарта британской BBC «Важнейшие мюзиклы».\n
79	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Диккенс Чарльз	\N	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/e/e9/Charles_Dickens_circa_1860s.png/274px-Charles_Dickens_circa_1860s.png	\N
14	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Райс Энн	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/5/55/Anne_Rice.jpg/210px-Anne_Rice.jpg	Энн Райс (англ. Anne Rice, имя при рождении — Говард Аллен О’Брайен (англ. Howard Allen O’Brien); род. 4 октября 1941, Новый Орлеан, Луизиана, США) — американская писательница, сценарист и продюсер. Наибольшую известность писательнице принёс роман «Интервью с вампиром», который обязан своей популярностью одноимённому фильму.\n
15	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Вероника Рот	\N	США	http://upload.wikimedia.org/wikipedia/commons/thumb/6/67/Veronica_Roth_March_18%2C_2014_%28cropped%29.jpg/274px-Veronica_Roth_March_18%2C_2014_%28cropped%29.jpg	Вероника Рот (англ. Veronica Roth, 19 августа 1988) — современная писательница в стиле антиутопии и фантастики, автор серии книг «Дивергент», по трём из которых была поставлена одноимённая экранизация с Шейлин Вудли в главной роли[1][2].\n
17	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Гейман Нил	1960-02-10	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/Kyle-cassidy-neil-gaiman-April-2013.jpg/220px-Kyle-cassidy-neil-gaiman-April-2013.jpg	\N
18	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Коэльо Пауло	\N	Бразилия	http://upload.wikimedia.org/wikipedia/commons/thumb/0/0b/Paulo_Coelho_nrkbeta.jpg/274px-Paulo_Coelho_nrkbeta.jpg	Па́уло Коэ́льо[6] (порт. Paulo Coelho [ˈpawlu koˈeʎu]; род. 24 августа 1947, Рио-де-Жанейро) — бразильский прозаик и поэт. Опубликовал в общей сложности более 20 книг — романы, комментированные антологии, сборники коротких рассказов-притч. В России прославился после издания «Алхимика», долго остававшегося в первой десятке бестселлеров. Общий тираж его книг на всех языках превышает 300 миллионов[7].\n
19	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Мид Райчел	\N	США	http://upload.wikimedia.org/wikipedia/commons/c/cc/RichelleMead.jpg	Райчел Мид (англ. Richelle Mead, произносится Рише́ль Мид; род. 12 ноября 1976, штат Мичиган, США) — американская писательница, работающая в жанрах ужасы, фэнтези, мистика, популярный американский автор городского фэнтези для взрослых и подростков[5].\n
20	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Хольбайн,  Деви	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/7/7f/Hohlbein_Wolfgang_Autor_floersheim_main_290607.jpg/225px-Hohlbein_Wolfgang_Autor_floersheim_main_290607.jpg	\N
21	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Малышев Игорь	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/d/db/%D0%98%D0%B3%D0%BE%D1%80%D1%8C_%D0%90%D0%BB%D0%B5%D0%BA%D1%81%D0%B0%D0%BD%D0%B4%D1%80%D0%BE%D0%B2%D0%B8%D1%87_%D0%9C%D0%B0%D0%BB%D1%8B%D1%88%D0%B5%D0%B2_2018.jpg/274px-%D0%98%D0%B3%D0%BE%D1%80%D1%8C_%D0%90%D0%BB%D0%B5%D0%BA%D1%81%D0%B0%D0%BD%D0%B4%D1%80%D0%BE%D0%B2%D0%B8%D1%87_%D0%9C%D0%B0%D0%BB%D1%8B%D1%88%D0%B5%D0%B2_2018.jpg	Игорь Александрович Малышев (род. 1972) — российский-русский писатель, публицист.\n
22	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Стокер Брэм	1847-02-08	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/3/34/Bram_Stoker_1906.jpg/220px-Bram_Stoker_1906.jpg	\N
24	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Сапковский Анджей	\N	Польша	http://upload.wikimedia.org/wikipedia/commons/thumb/7/76/Andrzej_Sapkowski_-_Lucca_Comics_and_Games_2015_2.JPG/274px-Andrzej_Sapkowski_-_Lucca_Comics_and_Games_2015_2.JPG	\N
25	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Стюарт Мери	\N	Великобритания	http://upload.wikimedia.org/wikipedia/ru/4/44/%D0%9C%D1%8D%D1%80%D0%B8_%D0%A1%D1%82%D1%8E%D0%B0%D1%80%D1%82.jpeg	\N
26	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Коллинз Сьюзен	1962-04-10	США	http://upload.wikimedia.org/wikipedia/commons/thumb/b/b9/Suzanne_Collins_David_Shankbone_2010.jpg/200px-Suzanne_Collins_David_Shankbone_2010.jpg	Сью́зен Ко́ллинз (англ. Suzanne Collins; родилась 10 августа 1962) — американская писательница, автор многочисленных сценариев к детским телепрограммам и мультфильмам, рассказов для детей, а также известная как создательница двух популярных книжных серий для молодежи: «Хроники Подземья» и «Голодные игры». Тираж первых двух романов трилогии «Голодные игры», ставших бестселлерами, превысил 2 миллиона экземпляров[6]. Трилогия экранизирована[7]: в России фильм по первому роману вышел на экраны 22 марта 2012, по второму — 21 ноября 2013, 1-я часть фильма по третьему роману вышла 21 ноября 2014, а 2-я — 19 ноября 2015.\n
27	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Риордан Рик	1964-02-05	США	http://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/Rick_riordan_2007.jpg/274px-Rick_riordan_2007.jpg	Рик Риордан[4] (англ. Rick Riordan; 5 июня 1964 года) — американский писатель, наиболее известен как автор серии романов про Перси Джексона.\n
28	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Толкин Джон	\N	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/6/66/J._R._R._Tolkien%2C_1940s.jpg/263px-J._R._R._Tolkien%2C_1940s.jpg	Джон Ро́нальд[12] Ру́эл То́лкин[13] (англ. John Ronald Reuel Tolkien[14]; 3 января 1892 года, Блумфонтейн, Оранжевая Республика — 2 сентября 1973 года, Борнмут, Англия) — английский писатель и поэт, переводчик, лингвист, филолог.\n
29	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Хобб Робин	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Robin_Hobb_20060929_Fnac_01.jpg/266px-Robin_Hobb_20060929_Fnac_01.jpg	\N
30	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Кассандра Клэр	\N	США	http://upload.wikimedia.org/wikipedia/commons/thumb/0/02/Cassandra_Clare_by_Gage_Skidmore%2C_2013_b.jpg/274px-Cassandra_Clare_by_Gage_Skidmore%2C_2013_b.jpg	Кассандра Клэр (англ. Cassandra Clare; настоящее имя — Джудит Румельт  (англ. Judith Rumelt); род. 31 июля 1973, Тегеран, Иран) — американская писательница. Наиболее известна как автор серии книг «Орудия смерти» и её приквела «Адские механизмы».\n
31	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Паолини Кристофер	\N	США	http://upload.wikimedia.org/wikipedia/commons/thumb/2/23/Christopher_Paolini_2019.jpg/274px-Christopher_Paolini_2019.jpg	Кристофер Паолини (англ. Christopher Paolini; род. 17 ноября 1983 года) — американский писатель, автор тетралогии в стиле фэнтези «Эрагон».\n
32	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Харрис Шарлин	1951-02-25	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Charlaine_Harris.JPG/200px-Charlaine_Harris.JPG	Шарли́н Ха́ррис (англ. Charlaine Harris) — американская писательница, автор четырёх успешных детективных книжных сериалов[9], в том числе и о Суки Стакхаус (англ. Sookie Stackhouse, возможны варианты перевода Соки или Сьюки), по мотивам которого создан драматический телевизионный сериал «Настоящая кровь».\n
33	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Булгаков Михаил	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Bu%C5%82hakow.jpg/274px-Bu%C5%82hakow.jpg	\N
34	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Басё Мацуо	\N	Япония	http://upload.wikimedia.org/wikipedia/commons/thumb/0/02/Basho_by_Buson.jpg/175px-Basho_by_Buson.jpg	\N
35	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Лермонтов Михаил Юрьевич	\N	Российская империя	http://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Mikhail_lermontov.jpg/274px-Mikhail_lermontov.jpg	Михаи́л Ю́рьевич Ле́рмонтов[10] (3 [15] октября 1814, Москва — 15 [27] июля 1841, Пятигорск) — русский поэт, прозаик, драматург, художник. Творчество Лермонтова, в котором сочетаются гражданские, философские и личные мотивы, отвечавшие насущным потребностям духовной жизни русского общества, ознаменовало собой новый расцвет русской литературы и оказало большое влияние на виднейших русских писателей и поэтов XIX и XX веков. Произведения Лермонтова получили большой отклик в живописи, театре, кинематографе. Его стихи стали подлинным кладезем для оперного, симфонического и романсового творчества. Многие из них стали народными песнями[11].\n
36	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Шекспир Уильям	\N	Королевство Англия	http://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Hw-shakespeare.png/274px-Hw-shakespeare.png	\N
37	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Ростан Эдмонд	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Edmond_Rostand.jpg/274px-Edmond_Rostand.jpg	Эдмо́н Роста́н (фр. Edmond Eugène Alexis Rostand; 1 апреля 1868 (1868-04-01), Марсель, Франция — 2 декабря 1918, Париж, Франция) — французский поэт и драматург неоромантического направления.\n
38	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Филатов Леонид	\N	\N	http://upload.wikimedia.org/wikipedia/ru/thumb/3/30/Leonid_Filatov_1988.jpg/250px-Leonid_Filatov_1988.jpg	Леони́д Алексе́евич Фила́тов (24 декабря 1946, Казань, СССР — 26 октября 2003, Москва, Россия) — советский и российский актёр театра и кино, кинорежиссёр, поэт, драматург, публицист, телеведущий; народный артист России (1995)[1]. Лауреат Государственной премии России (1996)[2].\n
39	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Гафт Валентин	2020-02-12	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/6/68/Valentin_Gaft_%28mos.ru%2C_cropped%29_01.jpg/274px-Valentin_Gaft_%28mos.ru%2C_cropped%29_01.jpg	\N
101	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Солнце Ирина	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/8/82/Irina_Nelson.jpg/274px-Irina_Nelson.jpg	\N
43	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Аверченко Аркадий	\N	\N	http://upload.wikimedia.org/wikipedia/commons/7/7d/Arkady_Averchenko_7.gif	Арка́дий Тимофе́евич Аве́рченко (15 [27] марта 1880[1], Севастополь — 12 марта 1925, Прага) — русский писатель, сатирик, драматург и театральный критик, редактор журналов «Сатирикон» (1908—1913) и «Новый Сатирикон» (1913—1918)[2].\n
44	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Раневская Фаина	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/%D0%A4%D0%B0%D0%B8%D0%BD%D0%B0_%D0%A0%D0%B0%D0%BD%D0%B5%D0%B2%D1%81%D0%BA%D0%B0%D1%8F_%D0%B2_%D0%91%D0%B0%D0%BA%D1%83.jpg/260px-%D0%A4%D0%B0%D0%B8%D0%BD%D0%B0_%D0%A0%D0%B0%D0%BD%D0%B5%D0%B2%D1%81%D0%BA%D0%B0%D1%8F_%D0%B2_%D0%91%D0%B0%D0%BA%D1%83.jpg	Фаи́на Гео́ргиевна (Григо́рьевна) Ране́вская (урождённая Фанни Ги́ршевна Фе́льдман; 15 [27] августа 1896, Таганрог — 19 июля 1984, Москва) — русская и советская актриса театра и кино; лауреат трёх Сталинских премий (1949, 1951, 1951), народная артистка СССР (1961)[2]. Кавалер ордена Ленина (1976)[3][4].\n
48	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Кун Николай	1940-02-28	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/e/ef/%D0%9D.%D0%90._%D0%9A%D1%83%D0%BD.jpg/274px-%D0%9D.%D0%90._%D0%9A%D1%83%D0%BD.jpg	Никола́й Альбе́ртович Кун (21 мая 1877, Москва — 28 декабря 1940 или 28 октября 1940[1], Черкизово, Московская область) — русский историк, писатель, педагог; автор популярной книги «Легенды и мифы Древней Греции», выдержавшей множество изданий на языках народов бывшего СССР и основных европейских языках, профессор МГУ.\n
63	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Беляев Александр	2020-02-20	СССР	http://upload.wikimedia.org/wikipedia/commons/thumb/b/b7/2018-BelyaevA-ShvarcE.jpg/274px-2018-BelyaevA-ShvarcE.jpg	Алекса́ндр Вади́мович Беля́ев (5 января 1949, Москва — 20 июля 2020, там же) — советский и российский географ-гидролог, кандидат географических наук, ведущий ряда телепередач на канале НТВ. Заместитель директора Института географии РАН по научным вопросам (2015)[1], автор около сотни научных публикаций. Член экспертного совета национальной премии «Хрустальный компас».\n
64	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Олди Генри Лайон	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/2/25/H._L._Oldie.jpg/250px-H._L._Oldie.jpg	\N
50	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Апдайк Джон	1932-05-18	США	http://upload.wikimedia.org/wikipedia/commons/thumb/1/10/Updike_29.jpg/140px-Updike_29.jpg	Джон Хо́йер А́пдайк (англ. John Hoyer Updike; 18 марта 1932 года, Рединг, Пенсильвания, США — 27 января 2009 года, Данверс (англ.)русск., Массачусетс, там же) — известный американский писатель, поэт и литературный критик, автор 23 романов и 45 других книг: сборников рассказов, стихотворений, эссе. На протяжении многих десятилетий публиковал рассказы и рецензии в журнале The New Yorker. Лауреат ряда американских литературных премий, включая две Пулитцеровские премии (за романы «Кролик разбогател» и «Кролик успокоился»)[6][7].\n
51	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Матесон Ричард	\N	США	http://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Richard_Matheson.jpg/200px-Richard_Matheson.jpg	Ри́чард Мэ́тисон (англ. Richard Burton Matheson; 20 февраля 1926, Аллендэйл (англ.)русск., Нью-Джерси, США — 23 июня 2013[5], Лос-Анджелес, США) — американский писатель и сценарист, работавший в жанрах фэнтези, ужасы и научная фантастика.\n
66	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Уэллс Герберт	1866-02-21	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/4/4b/H.G._Wells_by_Beresford.jpg/274px-H.G._Wells_by_Beresford.jpg	Ге́рберт Джордж Уэ́ллс (англ. Herbert George Wells; 21 сентября 1866, Бромли, Большой Лондон, Англия, Великобритания — 13 августа 1946, Лондон, Большой Лондон, Англия, Великобритания) — английский писатель и публицист. Автор известных научно-фантастических романов «Машина времени», «Человек-невидимка», «Война миров» и др. Представитель критического реализма. Сторонник фабианского социализма.\n
53	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Кинг Стивен	\N	США	http://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/Stephen_King%2C_Comicon.jpg/220px-Stephen_King%2C_Comicon.jpg	Сти́вен Э́двин Кинг (англ. Stephen Edwin King; род. 21 сентября 1947 (1947-09-21), Портленд, Мэн, США) — американский писатель, работающий в разнообразных жанрах, включая ужасы, триллер, фантастику, фэнтези, мистику, драму; получил прозвище «Король ужасов». Продано более 350 миллионов экземпляров его книг[4], по которым было снято множество художественных фильмов и сериалов, телевизионных постановок, а также нарисованы комиксы. Кинг опубликовал 60 романов, в том числе семь под псевдонимом Ричард Бахман, и 5 научно-популярных книг.\n
55	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Гаррисон Гарри	\N	США	http://upload.wikimedia.org/wikipedia/commons/thumb/2/2e/Harry_Harrison_in_Moscow.jpg/260px-Harry_Harrison_in_Moscow.jpg	Га́рри Га́ррисон (англ. Harry Harrison), настоящее имя Ге́нри Ма́ксвелл Де́мпси (Henry Maxwell Dempsey; 12 марта 1925 года, Стамфорд, США — 15 августа 2012 года[2], Брайтон, Англия) — американский[3] писатель-фантаст и редактор.\n
57	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Гофман Эрнст	\N	Королевство Пруссия	http://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/E._T._A._Hoffmann%2C_autorretrato.jpg/274px-E._T._A._Hoffmann%2C_autorretrato.jpg	Эрнст Теодо́р Вильге́льм Го́фман (нем. Ernst Theodor Wilhelm Hoffmann; произ. Хофман; 24 января 1776, Кёнигсберг, Королевство Пруссия — 25 июня 1822, Берлин, Королевство Пруссия) — немецкий писатель-романтик, сказочник, композитор, художник, юрист. \n
58	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Стругацкие Аркадий и Борис	\N	СССР	http://upload.wikimedia.org/wikipedia/ru/7/77/%D0%90%D1%80%D0%BA%D0%B0%D0%B4%D0%B8%D0%B9_%D0%9D%D0%B0%D1%82%D0%B0%D0%BD%D0%BE%D0%B2%D0%B8%D1%87_%D0%A1%D1%82%D1%80%D1%83%D0%B3%D0%B0%D1%86%D0%BA%D0%B8%D0%B9._1980-%D0%B5.jpg	Арка́дий Ната́нович Струга́цкий (28 августа 1925, Батуми — 12 октября 1991, Москва) — русский советский[4] писатель, сценарист, переводчик, создавший в соавторстве с братом Борисом Стругацким (1933—2012) несколько десятков произведений, считающихся классикой современной научной и социальной фантастики.\n
59	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Бредбери Рей	1920-04-22	США	http://upload.wikimedia.org/wikipedia/commons/thumb/a/aa/Ray_Bradbury_%281975%29.jpg/260px-Ray_Bradbury_%281975%29.jpg	Рэй Ду́глас Брэ́дбери (англ. Ray Douglas Bradbury; 22 августа 1920 года, Уокиган, США — 5 июня 2012 года, Лос-Анджелес[6][8][9]) — американский писатель, известный по антиутопии «451 градус по Фаренгейту», циклу рассказов «Марсианские хроники» и частично автобиографической повести «Вино из одуванчиков»[10][11].\n
60	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Глуховский Дмитрий	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/f/f1/Espace_Shayol_-_Rencontre_avec_Dmitry_Glukhowsky_-_Jeudi_-_Utopiales_2014_-_P1960160_cropped.jpg/274px-Espace_Shayol_-_Rencontre_avec_Dmitry_Glukhowsky_-_Jeudi_-_Utopiales_2014_-_P1960160_cropped.jpg	Дми́трий Алексе́евич Глухо́вский (род. 12 июня 1979[1][2], Москва) — российский писатель, журналист, сценарист, радиоведущий и военный корреспондент.\n
61	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Желязны Роджер	\N	США	http://upload.wikimedia.org/wikipedia/ru/thumb/a/a3/Roger_Zelazny.jpg/274px-Roger_Zelazny.jpg	\N
62	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Пристли Джон Бойнтон	\N	Великобритания	http://upload.wikimedia.org/wikipedia/ru/thumb/6/6a/J._B._Priestley.jpg/274px-J._B._Priestley.jpg	Джон Бо́йнтон При́стли (англ. John Boynton Priestley, [dʒɒn ˈbɔɪntən ˈpristli]; 13 сентября 1894, Брадфорд — 14 августа 1984, Стратфорд-на-Эйвоне) — английский романист, автор эссе, драматург и театральный режиссёр.\n
65	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Лем Станислав	\N	\N	http://upload.wikimedia.org/wikipedia/commons/1/15/Stanislaw_Lem_by_Kubik_%28cropped%29.JPG	Стани́слав Ге́рман Лем (польск. Stanisław Herman Lem; 12 сентября 1921, Львов, Польша — 27 марта 2006, Краков, Польша) — польский философ[3][4][5][6], футуролог и писатель (фантаст, эссеист, сатирик, критик). Его книги переведены на 41 язык, продано более 30 млн экземпляров[7]. Автор фундаментального философского труда «Сумма технологии», в котором предвосхитил создание виртуальной реальности, искусственного интеллекта, а также развил идеи автоэволюции человека, сотворения искусственных миров и многие другие.\n
67	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Франк Илья	1990-02-22	СССР	http://upload.wikimedia.org/wikipedia/commons/thumb/8/8d/Ilya_Frank.jpg/274px-Ilya_Frank.jpg	Илья́ Миха́йлович Франк (10 (23) октября 1908, Санкт-Петербург — 22 июня 1990, Москва) — советский физик. Академик Академии наук СССР (1968). Лауреат Нобелевской премии (1958). Лауреат двух Сталинских премий (1946, 1953) и Государственной премии СССР (1971).\n
71	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Робертс Грегори Дэвид	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/d/d8/2020-_Profile_Photo_GDR.jpg/274px-2020-_Profile_Photo_GDR.jpg	Грегори Дэвид Робертс (англ. Gregory David Roberts, настоящее имя Грегори Джон Питер Смит англ. Gregory John Peter Smith; род. 21 июня 1952[1], Мельбурн, Австралия) — австралийский писатель, сценарист и прозаик, известный романом «Шантарам». В прошлом страдал героиновой зависимостью, а также признан судом виновным в ограблении банка, впоследствии совершил побег из тюрьмы Пентридж (англ.)русск. (Австралия), затем скрывался в Индии, где прожил около 10 лет.\n
74	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Распэ Рудольф Эрих	\N	Германия	http://upload.wikimedia.org/wikipedia/commons/thumb/0/03/Rudolf_Erich_Raspe.jpg/274px-Rudolf_Erich_Raspe.jpg	Рудо́льф Э́рих Ра́спе (иногда Распэ; нем. Rudolf Erich Raspe; 26 марта 1736 — 16 ноября 1794) — немецкий писатель, поэт и историк, известный как автор рассказов барона Мюнхгаузена, в которых повествование ведётся от его имени.\n
75	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Конан-Дойль Артур	\N	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/Arthur_Conan_Doyle_by_Walter_Benington%2C_1914.png/274px-Arthur_Conan_Doyle_by_Walter_Benington%2C_1914.png	Сэр А́ртур Игне́йшус Ко́нан Дойл (Дойль)[К 1][К 2] (англ. Sir Arthur Ignatius Conan Doyle; 22 мая 1859[1][2][3][…], Эдинбург, Великобритания[4] — 7 июля 1930[2][3][4][…], поместье Уиндлшем[d], Кроуборо[5]) — английский писатель[К 3][14][15][16][17] (по образованию врач) ирландского происхождения, автор многочисленных приключенческих, исторических, публицистических, фантастических и юмористических произведений. Создатель классических персонажей детективной, научно-фантастической и историко-приключенческой литературы: гениального сыщика Шерлока Холмса, эксцентричного профессора Челленджера, бравого кавалерийского офицера Жерара, благородного рыцаря сэра Найджела. Со второй половины 1910-х годов и до конца жизни — активный сторонник и пропагандист идей спиритуализма.\n
76	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Сабатини Рафаэль	1950-02-13	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Portrait_of_Rafael_Sabatini.jpg/274px-Portrait_of_Rafael_Sabatini.jpg	Рафаэ́ль Сабати́ни[4] (итал. Rafael Sabatini; 29 апреля 1875, Ези близ Анконы, Италия — 13 февраля 1950, Швейцария) — английский и итальянский писатель, прославившийся приключенческими историческими романами, в частности, романами о капитане Бладе.\n
77	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Кизи Кен	1935-02-17	США	http://upload.wikimedia.org/wikipedia/ru/thumb/9/90/%D0%9A%D0%B5%D0%BD_%D0%9A%D0%B8%D0%B7%D0%B8.jpg/271px-%D0%9A%D0%B5%D0%BD_%D0%9A%D0%B8%D0%B7%D0%B8.jpg	Ке́ннет Э́лтон «Кен» Ки́зи (англ. Kenneth Elton "Ken" Kesey [ˈkiːziː]; 17 сентября 1935 — 10 ноября 2001) — американский писатель, драматург, журналист. Известен, в частности, как автор романа «Пролетая над гнездом кукушки». Автор считается одним из главных писателей бит-поколения и поколения хиппи, оказавшим большое влияние на формирование этих движений и их культуру.\n
78	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Дефо Даниэль	\N	Королевство Англия	http://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Daniel_Defoe_Kneller_Style.jpg/274px-Daniel_Defoe_Kneller_Style.jpg	Даниель Дефо́ (имя при рождении Даниель Фо; около 1660, район Криплгейт[en], Лондон — 24 апреля 1731, район Сприндфел, Лондон) — английский писатель и публицист. Известен главным образом как автор романа «Робинзон Крузо». Дефо считают одним из первых сторонников романа как жанра. Он помог популяризовать этот жанр в Великобритании, а некоторые считают его одним из основателей английского романа. Дефо — плодовитый и разнообразный писатель, он написал более 500 книг, памфлетов и журналов на разные темы (политика, экономика, криминал, религия, брак, психология, сверхъестественное и др.). Он был также основоположником экономической журналистики. В публицистике пропагандировал здравомыслие, выступал в защиту веротерпимости и свободы слова.\n
80	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Воронкова Любовь	\N	\N	http://upload.wikimedia.org/wikipedia/ru/thumb/2/2e/%D0%92%D0%BE%D1%80%D0%BE%D0%BD%D0%BA%D0%BE%D0%B2%D0%B0_%D0%9B%D1%8E%D0%B1%D0%BE%D0%B2%D1%8C_%D0%A4%D1%91%D0%B4%D0%BE%D1%80%D0%BE%D0%B2%D0%BD%D0%B0_%281906%E2%80%941976%29.png/274px-%D0%92%D0%BE%D1%80%D0%BE%D0%BD%D0%BA%D0%BE%D0%B2%D0%B0_%D0%9B%D1%8E%D0%B1%D0%BE%D0%B2%D1%8C_%D0%A4%D1%91%D0%B4%D0%BE%D1%80%D0%BE%D0%B2%D0%BD%D0%B0_%281906%E2%80%941976%29.png	Любо́вь Фёдоровна Воронко́ва (1906 — 1976) — советская писательница, автор многих детских книг и цикла исторических повестей для детей. Член Союза писателей СССР.\n
81	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Стивенсон Роберт Льюис	1850-02-13	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Robert_Louis_Stevenson_by_Henry_Walter_Barnett_bw.jpg/230px-Robert_Louis_Stevenson_by_Henry_Walter_Barnett_bw.jpg	Ро́берт Лью́ис Бэлфур Сти́венсон (англ. Robert Louis Balfour Stevenson; 13 ноября 1850 (1850-11-13), Эдинбург — 3 декабря 1894, Уполу, Самоа) — шотландский писатель и поэт, автор приключенческих романов и повестей, крупнейший представитель неоромантизма.\n
82	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Брусникин Анатолий	\N	Россия	http://upload.wikimedia.org/wikipedia/commons/thumb/5/56/B._Akunin.jpg/266px-B._Akunin.jpg	Бори́с Аку́нин (настоящее имя Григо́рий Ша́лвович Чхартишви́ли, груз. გრიგორი შალვას ძე ჩხარტიშვილი; род. 20 мая 1956 года, Зестафони, Грузинская ССР, СССР) — русский писатель, учёный-японист, литературовед, переводчик, общественный деятель. Также публиковался под литературными псевдонимами Анна Борисова и Анатолий Брусникин.\n
83	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Дюма Александр	\N	Франция	http://upload.wikimedia.org/wikipedia/commons/thumb/f/f1/Nadar_-_Alexander_Dumas_p%C3%A8re_%281802-1870%29_-_Google_Art_Project_2.jpg/274px-Nadar_-_Alexander_Dumas_p%C3%A8re_%281802-1870%29_-_Google_Art_Project_2.jpg	Алекса́ндр Дюма́ (фр. Alexandre Dumas; 24 июля 1802, Виллер-Котре — 5 декабря 1870, Пюи) — французский писатель, драматург и журналист. Один из самых читаемых французских авторов, мастер приключенческого романа. Две самые известные его книги — «Граф Монте-Кристо» и «Три мушкетёра» — были написаны в 1844—1845 гг. Под именем Дюма вышло огромное количество исторических романов, в написании которых участвовали литературные подёнщики. Всего за авторством Дюма опубликовано не менее 100 000 страниц[7]. Помимо романов, его перу принадлежат также пьесы, статьи и книги о путешествиях.\n
84	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Гюго Виктор	1802-02-26	Франция	http://upload.wikimedia.org/wikipedia/commons/thumb/e/e6/Victor_Hugo_by_%C3%89tienne_Carjat_1876_-_full.jpg/274px-Victor_Hugo_by_%C3%89tienne_Carjat_1876_-_full.jpg	Викто́р Мари́ Гюго́[5] (фр. Victor Marie Hugo, французский: [viktɔʁ maʁi yɡo] ( слушать);; 26 февраля 1802, Безансон — 22 мая 1885, Париж) — французский писатель (поэт, прозаик и драматург), одна из главных фигур французского романтизма. Член Французской академии (1841).\n
85	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Лондон Джек	1876-02-12	США	http://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Jack_London_Genthe.jpg/274px-Jack_London_Genthe.jpg	Джек Ло́ндон (англ. Jack London; при рождении Джон Гри́ффит Че́йни, John Griffith Chaney; 12 января 1876[1][2][3][…], Сан-Франциско, Калифорния[1] — 22 ноября 1916[1][2][3][…], Глен-Эллен[d], Калифорния, США[1]) — американский писатель и журналист, военный корреспондент, общественный деятель, социалист. Наиболее известен как автор приключенческих рассказов и романов.\n
86	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Алексеев Сергей	\N	Россия	http://upload.wikimedia.org/wikipedia/commons/thumb/4/4b/%D0%A1%D0%B5%D1%80%D0%B3%D0%B5%D0%B9_%D0%A2%D1%80%D0%BE%D1%84%D0%B8%D0%BC%D0%BE%D0%B2%D0%B8%D1%87_%D0%90%D0%BB%D0%B5%D0%BA%D1%81%D0%B5%D0%B5%D0%B2.jpg/274px-%D0%A1%D0%B5%D1%80%D0%B3%D0%B5%D0%B9_%D0%A2%D1%80%D0%BE%D1%84%D0%B8%D0%BC%D0%BE%D0%B2%D0%B8%D1%87_%D0%90%D0%BB%D0%B5%D0%BA%D1%81%D0%B5%D0%B5%D0%B2.jpg	Сергей Трофимович Алексеев (род. 20 января 1952 года) — российский писатель национал-патриотического направления. Творчество оказало влияние на развитие идей родноверия (славянского неоязычества)[2]. Член Союза писателей России[1].\n
87	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Твен Марк	\N	США	http://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/Mark_Twain_by_AF_Bradley.jpg/274px-Mark_Twain_by_AF_Bradley.jpg	\N
88	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Ян Василий Григорьевич	\N	\N	http://upload.wikimedia.org/wikipedia/ru/5/5f/Yan_vasilij.jpg	Васи́лий Григо́рьевич Ян (настоящая фамилия — Янчеве́цкий; 23 декабря 1874 года (4 января 1875 года), Киев — 5 августа 1954, Звенигород) — русский советский писатель, публицист, поэт и драматург, сценарист, педагог. Автор популярных исторических романов. Сын антиковеда Григория Янчевецкого, брат журналиста и востоковеда Дмитрия Янчевецкого.\n
89	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Скотт Вальтер	1771-04-15	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Sir_Walter_Scott_-_Raeburn-2.jpg/274px-Sir_Walter_Scott_-_Raeburn-2.jpg	\N
90	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Дрюон Морис	1918-02-23	Франция	http://upload.wikimedia.org/wikipedia/commons/thumb/9/99/Maurice_Druon_2003_Orenburg_crop.jpg/250px-Maurice_Druon_2003_Orenburg_crop.jpg	Мори́с Самюэ́ль Роже́ Шарль Дрюо́н (фр. Maurice Samuel Roger Charles Druon; 23 апреля 1918 (1918-04-23), Париж, Франция — 14 апреля 2009, там же) — французский писатель, член Французской академии (1967), министр культуры Франции (1973—1974).\n
91	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Корнуэлл Бернард	\N	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/7/7c/Bernard_Cornwell.jpg/225px-Bernard_Cornwell.jpg	Бе́рнард Ко́рнуэлл (англ. Bernard Cornwell, 23 февраля 1944) — английский писатель и репортёр, автор исторических романов про королевского стрелка Ричарда Шарпа.\n
92	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Джером Джером Клапка	\N	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Jerome_K._Jerome_%287893553318%29.jpg/200px-Jerome_K._Jerome_%287893553318%29.jpg	Джеро́м Кла́пка Джеро́м (англ. Jerome Klapka Jerome, 2 мая 1859, Уолсолл, графство Стаффордшир — 14 июня 1927, Нортгемптон) — английский писатель-юморист, драматург, постоянный сотрудник сатирического журнала «Панч», редактировал в 1892—1897 годы журналы «Лентяй» (англ. Idler) и «Сегодня» (англ. To-day).\n
93	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Свифт Джонатан	\N	Королевство Ирландия	http://upload.wikimedia.org/wikipedia/commons/thumb/7/7e/Jervas-JonathanSwift.jpg/274px-Jervas-JonathanSwift.jpg	Джо́натан Свифт (англ. Jonathan Swift; 30 ноября 1667 года, Дублин, Ирландия — 19 октября 1745 года, там же) — англо-ирландский писатель-сатирик, публицист, философ, поэт и общественный деятель, англиканский священник.\n
94	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Буссенар Луи Анри	\N	Франция	http://upload.wikimedia.org/wikipedia/commons/thumb/4/48/Louis-Henri_Boussenard.jpg/200px-Louis-Henri_Boussenard.jpg	\N
95	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Хаггард Генри Райдер	\N	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/3/39/H._Rider_%28Henry_Rider%29_Haggard.tif/lossy-page1-274px-H._Rider_%28Henry_Rider%29_Haggard.tif.jpg	Сэр Ге́нри Ра́йдер Ха́ггард (в дореволюционной русской транскрипции Гаггард[1], англ. Henry Rider Haggard; 22 июня 1856 года, Брейдэнем[en], Норфолк, Англия — 14 мая 1925 года, Лондон) — английский писатель, представитель викторианской и эдвардианской приключенческой литературы. Несмотря на определённое воздействие на мировоззрение современников, остался писателем второго ряда, а часть его произведений перешла в разряд детской литературы[2]. Считается основоположником жанра «затерянные миры» (наряду с Артуром Конан Дойлем). Произведения Хаггарда (особенно цикл про Аллана Квотермейна и бессмертную Айшу) до сих пор пользуются популярностью, переиздаются и экранизируются.\n
96	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Верн Жюль Габриэль	1828-02-08	Франция	http://upload.wikimedia.org/wikipedia/commons/thumb/d/d1/F%C3%A9lix_Nadar_1820-1910_portraits_Jules_Verne_%28restoration%29.jpg/274px-F%C3%A9lix_Nadar_1820-1910_portraits_Jules_Verne_%28restoration%29.jpg	Жюль Габрие́ль Верн[8] (фр. Jules Gabriel Verne; 8 февраля 1828[1][2][3][…], Нант[5][6] — 24 марта 1905[1][4][3][…], Амьен[5][6]) — французский писатель, классик приключенческой литературы, один из основоположников жанра научной фантастики, гуманист. Член Французского Географического общества. По статистике ЮНЕСКО, книги Жюля Верна занимают второе место по переводимости в мире, уступая лишь произведениям Агаты Кристи[9].\n
97	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Жуковский В.А	\N	Российская империя	http://upload.wikimedia.org/wikipedia/commons/thumb/4/4b/Bryullov_portrait_of_Zhukovsky.jpg/274px-Bryullov_portrait_of_Zhukovsky.jpg	Васи́лий Андре́евич Жуко́вский (29 января [9 февраля] 1783, Мишенское, Белёвский уезд, Тульская губерния, Российская империя[1] — 12 [24] апреля 1852, Баден-Баден, Великое герцогство Баден[1]) — русский поэт, один из основоположников романтизма в русской поэзии, сочинивший множество элегий, посланий, песен, романсов, баллад и эпических произведений. Также известен как переводчик поэзии и прозы, литературный критик, педагог. В 1817—1841 годах учитель русского языка великой княгини, а затем императрицы Александры Фёдоровны и наставник цесаревича Александра Николаевича. Тайный советник (1841). Автор слов государственного гимна Российской империи «Боже, Царя храни!» (1833).\n
98	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Алигьери Данте	\N	Флорентийская республика	http://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Portrait_de_Dante.jpg/263px-Portrait_de_Dante.jpg	Да́нте Алигье́ри (итал. Dante Alighieri, полное имя Дуранте дельи Алигьери, последняя декада мая[⇨] 1265 (1265) — в ночь с 13 на 14 сентября 1321) — итальянский поэт, мыслитель, богослов, один из основоположников литературного итальянского языка, политический деятель. Создатель «Комедии» (позднее получившей эпитет «Божественной», введённый Боккаччо), в которой был дан синтез позднесредневековой культуры[3].\n
99	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Бокаччо Джованни	\N	Флорентийская республика	http://upload.wikimedia.org/wikipedia/commons/thumb/2/29/Andrea_del_Castagno_Giovanni_Boccaccio_c_1450.jpg/255px-Andrea_del_Castagno_Giovanni_Boccaccio_c_1450.jpg	Джова́нни Бокка́ччо (итал. Giovanni Boccaccio; 16 июня[3] 1313, Чертальдо или Флоренция, Италия (по некоторым источникам), или Париж, Франция[4] — 21 декабря 1375, Чертальдо, Италия) — итальянский писатель и поэт, представитель литературы эпохи Раннего Возрождения, который наряду со своими кумирами — Данте и Петраркой — оказал существенное влияние на развитие всей европейской культуры.\n
102	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Ахерн Сесилия	\N	Ирландия	http://upload.wikimedia.org/wikipedia/commons/thumb/3/34/Cecelia_Ahern.jpg/266px-Cecelia_Ahern.jpg	Сеси́лия Ахе́рн (англ. Cecelia Ahern, ирл. Cecelia Ní hEachthairn; род. 30 сентября 1981 года, Дублин, Ирландия) — писательница, автор любовных романов.\n
104	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Бронте Шарлотта	\N	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/8/86/Charlotte_Bronte_coloured_drawing.png/250px-Charlotte_Bronte_coloured_drawing.png	Шарло́тта Бро́нте (англ. Charlotte Brontë; 21 апреля 1816 (1816-04-21), Торнтон, Великобритания — 31 марта 1855, Хоэрт, Великобритания), псевдоним Каррер Белл (Currer Bell) — английская поэтесса и романистка.\n
105	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Гарди Томас	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/6/6e/Thomashardy_restored.jpg/200px-Thomashardy_restored.jpg	То́мас Ха́рди (Томас Гарди, англ. Thomas Hardy; 2 июня 1840, Аппер-Бокхэмптон, графство Дорсет — 11 января 1928, Макс-Гейт близ Дорчестера) — крупнейший английский писатель и поэт поздневикторианской эпохи.\n
106	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Кокс Мэгги	\N	\N	http://upload.wikimedia.org/wikipedia/ru/0/04/%D0%9F%D1%80%D0%B8%D0%BA%D1%83%D0%BF_%28%D0%BA%D0%B8%D0%BD%D0%BE%29.jpg	\N
107	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Джеймс Элоиза	\N	\N	http://upload.wikimedia.org/wikipedia/ru/thumb/9/90/Sopranos_ep412.jpg/274px-Sopranos_ep412.jpg	\N
108	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Беллами Кэтрин	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/Ralph_Bellamy_still.jpg/220px-Ralph_Bellamy_still.jpg	Ральф Беллами (англ. Ralph Bellamy; 17 июня 1904, Чикаго — 29 ноября 1991, Санта-Моника) — американский актёр.\n
109	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Остин Джейн	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Jane_Austen_coloured_version.jpg/300px-Jane_Austen_coloured_version.jpg	\N
110	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Маккалоу Колин	\N	\N	http://upload.wikimedia.org/wikipedia/ru/thumb/7/74/Colleen-mccullough.jpg/274px-Colleen-mccullough.jpg	\N
111	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Уэбб Кэтрин	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Veronica-Webb-Shankbone-2010-NYC.jpg/230px-Veronica-Webb-Shankbone-2010-NYC.jpg	Веро́ника Уэ́бб (англ. Veronica Webb; 25 февраля 1965, Детройт, Мичиган, США) — американская актриса, фотомодель, журналистка и телеведущая.\n
112	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Спир Флора	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/5/50/Prof._A.S._Hitchcock_of_Ag._Dept.%2C_9-2-24_LCCN2016849476_%28cropped%29.jpg/274px-Prof._A.S._Hitchcock_of_Ag._Dept.%2C_9-2-24_LCCN2016849476_%28cropped%29.jpg	\N
115	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Робертс Нора	\N	США	http://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/NoraRoberts.jpg/274px-NoraRoberts.jpg	Нора Робертс (англ. Nora Roberts, при рождении  — Элеонора Мари Робертсон Ауфем-Бринк Уайлдер англ. Eleanor Marie Robertson Aufem-Brinke Wilder; род. 10 октября 1950, Силвер-Спринг, Мэриленд) — американская писательница, автор современных любовных[en] и детективных романов.\n
116	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Томпсон Доун	\N	\N	http://upload.wikimedia.org/wikipedia/commons/e/e8/Down_Low_1999.jpg	\N
118	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Рэдклифф Анна	\N	\N	http://upload.wikimedia.org/wikipedia/commons/6/61/Ann_Radcliffe.jpg	Анна Радклиф (англ. Ann Radcliffe, урождённая Уорд (англ. Ward); 9 июля 1764 — 7 февраля 1823) — английская писательница, одна из основательниц готического романа.\n
120	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Гюнтекин Решад Нури	\N	Османская империя	http://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/Re%C5%9Fat_Nuri_G%C3%BCntekin.jpg/150px-Re%C5%9Fat_Nuri_G%C3%BCntekin.jpg	\N
121	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Устинова Татьяна	\N	СССР	http://upload.wikimedia.org/wikipedia/commons/thumb/7/7d/Tatiana_Ustinova_20190703_202040.jpg/274px-Tatiana_Ustinova_20190703_202040.jpg	\N
122	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Акунин Борис	\N	Россия	http://upload.wikimedia.org/wikipedia/commons/thumb/5/56/B._Akunin.jpg/266px-B._Akunin.jpg	Бори́с Аку́нин (настоящее имя Григо́рий Ша́лвович Чхартишви́ли, груз. გრიგორი შალვას ძე ჩხარტიშვილი; род. 20 мая 1956 года, Зестафони, Грузинская ССР, СССР) — русский писатель, учёный-японист, литературовед, переводчик, общественный деятель. Также публиковался под литературными псевдонимами Анна Борисова и Анатолий Брусникин.\n
125	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Кристи Агата	\N	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Agatha_Christie.png/200px-Agatha_Christie.png	\N
126	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Симеон Жорж	\N	Франция	http://upload.wikimedia.org/wikipedia/commons/thumb/2/20/P%C3%A8re-Lachaise_-_Division_10_-_Serullas_02.jpg/253px-P%C3%A8re-Lachaise_-_Division_10_-_Serullas_02.jpg	Сначала военно-полевой аптекарь, затем главный начальник фармацевтической части в армии Наполеона во время походов против Германии, России и Италии. С 1825 г. профессор химии в парижском Jardin des plantes. С этого времени он стал одним из наиболее деятельных французских химиков, открыл йодистый азот, циануровую и хлорную кислоты, работал с йодистыми и бромистыми соединениями металлоидов — фосфора, углерода, селена, сурьмы, изучал сложные эфирокислоты[4].\n
127	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Коллинз Уилки	\N	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/b/bf/Wilkie-Collins.jpg/274px-Wilkie-Collins.jpg	Уи́льям Уи́лки Ко́ллинз (англ. William Wilkie Collins, 8 января 1824, Лондон — 23 сентября 1889, Лондон) — английский писатель, драматург, автор 27 романов, 15 пьес и более чем полусотни рассказов.[6]\n
128	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Полякова Татьяна	\N	\N	http://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/Tatyana_Polyakova.jpg/250px-Tatyana_Polyakova.jpg	Татья́на Поляко́ва (настоящее имя — Татья́на Ви́кторовна Рога́нова; род. 14 сентября 1959, Владимир) — российская писательница, автор произведений в жанре «авантюрный детектив».\n
129	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Литвиновы Анна и Сергей	\N	СССР	http://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/Sergey_Litvinov_-_MIBF_2018_-_1927.jpg/274px-Sergey_Litvinov_-_MIBF_2018_-_1927.jpg	\N
130	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Хмелевская Иоанна	\N	Польша	http://upload.wikimedia.org/wikipedia/ru/thumb/7/7d/Joanna_Chmelevska.gif/230px-Joanna_Chmelevska.gif	Иоа́нна Хмеле́вская (польск. Joanna Chmielewska), настоящее имя писательницы — Ирена Барбара Кун (Irena Barbara Kuhn), урождённая Ирена Барбара Иоанна Беккер[1] (Irena Barbara Joanna Becker; 2 апреля 1932, Варшава — 7 октября 2013, Варшава[2]) — польская писательница, автор иронических детективов и основоположник этого жанра для русских читателей.\n
46	2021-03-01 09:04:42.308428+00	2021-03-01 09:04:42.308428+00	Пэлем Грэнвилл	1881-02-15	Великобритания	http://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/PGWodehouse.jpg/274px-PGWodehouse.jpg	Сэр Пе́лам Гре́нвилл (Пи Джи) Ву́дхаус (Ву́дхауз; англ. Pelham Grenville "P. G." Wodehouse; 15 октября 1881 — 14 февраля 1975) — популярный английский писатель, драматург, комедиограф. Рыцарь-командор ордена Британской империи (KBE). Произведения Вудхауза, прежде всего, в юмористическом жанре, начиная с 1915 года пользовались неизменным успехом; высокие оценки его творчеству давали многие известные авторы, в том числе Редьярд Киплинг и Джордж Оруэлл. Наиболее известен цикл романов Вудхауза о молодом британском аристократе Берти Вустере и его находчивом камердинере Дживсе; во многом способствовал этой популярности британский телесериал «Дживс и Вустер» (1990—1993), где в главных ролях снялись Стивен Фрай и Хью Лори.\n
\.


--
-- Data for Name: book_files; Type: TABLE DATA; Schema: public; Owner: kurush
--

COPY public.book_files (publication_id, created_at, updated_at, file_path, file_type) FROM stdin;
1	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Вне циклов/Народ, или Когда-то мы были дельфинами.fb2	fb2
2	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Вне циклов/Очень веская причина поверить в Санта-Клауса.fb2	fb2
3	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Вне циклов/Темная сторона Солнца.fb2	fb2
4	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Вне циклов/Страта.fb2	fb2
5	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Вне циклов/Кот без дураков.fb2	fb2
6	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Вне циклов/Люди Ковра.fb2	fb2
7	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Вне циклов/Благие знамения.fb2	fb2
8	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/3. Смерть/02. Мрачный Жнец.fb2	fb2
9	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/3. Смерть/04. Санта-Хрякус.fb2	fb2
10	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/3. Смерть/Вертушки ночи (рассказ).fb2	fb2
11	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/3. Смерть/Смерть и Что Случается После (рассказ).fb2	fb2
12	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/3. Смерть/01. Мор, ученик Смерти.fb2	fb2
13	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/3. Смерть/03. Роковая музыка.fb2	fb2
14	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/3. Смерть/05. Вор Времени.fb2	fb2
15	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/6. Самостоятельные романы/01. Пирамиды.fb2	fb2
16	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/6. Самостоятельные романы/06. Пехотная баллада.fb2	fb2
17	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/6. Самостоятельные романы/04. Правда.fb2	fb2
18	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/6. Самостоятельные романы/05. Удивительный Морис и его ученые грызуны (ЛП).fb2	fb2
19	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/6. Самостоятельные романы/03. Мелкие боги.fb2	fb2
20	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/6. Самостоятельные романы/02. Движущиеся картинки.fb2	fb2
21	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/1. Ринсвинд, Коэн и волшебники/05. Интересные времена.fb2	fb2
22	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/1. Ринсвинд, Коэн и волшебники/04. Эрик, а также Ночная стража, ведьмы и Коэн-Варвар.fb2	fb2
23	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/1. Ринсвинд, Коэн и волшебники/08. Незримые Академики.fb2	fb2
24	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/1. Ринсвинд, Коэн и волшебники/06. Последний континент.fb2	fb2
25	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/1. Ринсвинд, Коэн и волшебники/01. Цвет волшебства.fb2	fb2
26	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/1. Ринсвинд, Коэн и волшебники/03. Посох и шляпа.fb2	fb2
27	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/1. Ринсвинд, Коэн и волшебники/07. Последний герой.fb2	fb2
28	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/1. Ринсвинд, Коэн и волшебники/02. Безумная звезда.fb2	fb2
29	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/1. Ринсвинд, Коэн и волшебники/Наука Плоского мира. Книга 2. Глобус.fb2	fb2
30	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/1. Ринсвинд, Коэн и волшебники/Наука Плоского Мира.fb2	fb2
31	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/1. Ринсвинд, Коэн и волшебники/Наука Плоского Мира III. Часы Дарвина (ЛП).fb2	fb2
32	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/2. Ведьмы/06. Carpe Jugulum. Хватай за горло!.fb2	fb2
33	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/2. Ведьмы/05. Маскарад.fb2	fb2
34	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/2. Ведьмы/08. Тиффани Эйкинг 1. Вольный народец (ЛП).fb2	fb2
35	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/2. Ведьмы/10. Тиффани Эйкинг 3. Зимних Дел Мастер (ЛП).fb2	fb2
36	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/2. Ведьмы/01. Творцы заклинаний.fb2	fb2
37	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/2. Ведьмы/09. Тиффани Эйкинг 2. Шляпа, полная небес… (ЛП).fb2	fb2
38	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/2. Ведьмы/07. Поваренная книга Нянюшки Огг.fb2	fb2
39	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/2. Ведьмы/11. Тиффани Эйкинг 4. Я надену чёрное (ЛП).fb2	fb2
40	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/2. Ведьмы/03. Ведьмы за границей.fb2	fb2
41	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/2. Ведьмы/04. Дамы и Господа.fb2	fb2
42	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/2. Ведьмы/02. Вещие сестрички.fb2	fb2
43	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/4. Городская Стража/06. Ночная стража.fb2	fb2
44	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/4. Городская Стража/02. К оружию! К оружию!.fb2	fb2
45	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/4. Городская Стража/08. Дело табак.fb2	fb2
46	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/4. Городская Стража/07. Шмяк!.fb2	fb2
47	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/4. Городская Стража/05. Пятый элефант.fb2	fb2
48	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/4. Городская Стража/01. Стража! Стража!.fb2	fb2
49	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/4. Городская Стража/04. Патриот.fb2	fb2
50	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/4. Городская Стража/03. Ноги из глины.fb2	fb2
51	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/5. Мойст фон Липвиг/01. Опочтарение (ЛП).fb2	fb2
52	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/5. Мойст фон Липвиг/03. На всех парах (ЛП).fb2	fb2
53	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Плоский мир/5. Мойст фон Липвиг/02. Делай Деньги (ЛП).fb2	fb2
54	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Книги номов/3. Крылья.fb2	fb2
55	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Книги номов/2. Землекопы.fb2	fb2
56	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Книги номов/1. Угонщики.fb2	fb2
57	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Джонни Максвелл/3. Джонни и бомба.fb2	fb2
58	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Джонни Максвелл/2. Джонни и мертвецы.fb2	fb2
59	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Джонни Максвелл/1. Только ты можешь спасти человечество.fb2	fb2
60	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Бесконечная Земля/1. Бесконечная земля.fb2	fb2
61	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Прачетт Терри/Бесконечная Земля/2. Бесконечная война.fb2	fb2
62	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/Сказки старого Вильнюса/г. Сказки старого Вильнюса.fb2	fb2
63	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/Сказки старого Вильнюса/е. Сказки старого Вильнюса.fb2.zip	zip
64	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/Сказки старого Вильнюса/в. Сказки старого Вильнюса.fb2.zip	zip
65	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/Сказки старого Вильнюса/д. Сказки старого Вильнюса.fb2.zip	zip
66	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/Сказки старого Вильнюса/а. Сказки старого Вильнюса.fb2.zip	zip
67	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/Сказки старого Вильнюса/ж. Сказки старого вильнюса.fb2.zip	zip
68	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/Сказки старого Вильнюса/б. Сказки старого Вильнюса.fb2	fb2
69	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/Ключ из желтого металла.zip	zip
70	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/а Лабиринт Ехо/а Лабиринт.zip	zip
71	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/а Лабиринт Ехо/б Волонтеры вечности.zip	zip
72	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/а Лабиринт Ехо/д Наваждения.zip	zip
73	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/а Лабиринт Ехо/з Лабиринт Мёнина.zip	zip
74	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/а Лабиринт Ехо/ж Болтливый мертвец.zip	zip
75	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/а Лабиринт Ехо/и  Гнезда Химер.zip	zip
76	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/а Лабиринт Ехо/к  Мой Рагнарёк.zip	zip
77	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/а Лабиринт Ехо/е Власть несбывшегося.zip	zip
78	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/а Лабиринт Ехо/в Простые волшебные вещи.zip	zip
79	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/а Лабиринт Ехо/г Темная сторона.zip	zip
80	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/Книга Одиночеств.zip	zip
81	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/Жалобная книга.zip	zip
82	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/в Сновидения Ехо/в. Вся правда о нас.fb2	fb2
83	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/в Сновидения Ехо/д. Сундук Мертвеца.zip	zip
84	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/в Сновидения Ехо/з. Так берегись.fb2	fb2
85	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/в Сновидения Ехо/е. Отдай моё сердце.zip	zip
86	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/в Сновидения Ехо/г. Я иду искать.fb2	fb2
87	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/в Сновидения Ехо/а. Мастер ветров и закатов.zip	zip
88	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/в Сновидения Ехо/ж. Мертвый ноль.zip	zip
89	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/в Сновидения Ехо/б. Слишком много кошмаров.zip	zip
90	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/Джингл-Ко.zip	zip
91	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/б Хроники Ехо/г Ворона на мосту.zip	zip
92	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/б Хроники Ехо/а Хроники Ехо.zip	zip
93	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/б Хроники Ехо/д Горе господина Гро.zip	zip
94	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/б Хроники Ехо/ж Дар Шаванахолы.zip	zip
95	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/б Хроники Ехо/е Обжора-хохотун.zip	zip
96	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/б Хроники Ехо/б Властелин Морморы.zip	zip
97	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/б Хроники Ехо/в Неуловимый Хабба Хэн.zip	zip
98	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Фрай Макс/б Хроники Ехо/з Тубурская игра.zip	zip
99	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Ле Гуин Урсула/Волшебник Земноморья/в На последнем берегу.zip	zip
100	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Ле Гуин Урсула/Волшебник Земноморья/г Техану.zip	zip
101	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Ле Гуин Урсула/Волшебник Земноморья/б Гробница Атуана.zip	zip
102	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Ле Гуин Урсула/Волшебник Земноморья/а Волшебник Земноморья.zip	zip
103	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мартин Джордж/Песнь льда и огня/г Пир стервятников.fb2.zip	zip
104	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мартин Джордж/Песнь льда и огня/в Буря мечей.zip	zip
105	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мартин Джордж/Песнь льда и огня/д Танец с драконами. Грезы и пыль.zip	zip
106	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мартин Джордж/Песнь льда и огня/б Битва королей.zip	zip
107	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мартин Джордж/Песнь льда и огня/а Игра престолов.zip	zip
108	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мартин Джордж/Песнь льда и огня/е Танец с драконами. Искры над пеплом.zip	zip
109	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мартин Джордж/Повести о Дунке и Эгге/а Межевой рыцарь.zip	zip
110	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мартин Джордж/Повести о Дунке и Эгге/г Таинственный рыцарь.zip	zip
111	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мартин Джордж/Повести о Дунке и Эгге/б Верный меч.zip	zip
112	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Леви Марк/а Встретиться вновь.zip	zip
113	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Леви Марк/д Семь дней творения.zip	zip
114	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Леви Марк/г Между небом и землей.zip	zip
115	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Леви Марк/е Следующий раз.zip	zip
116	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Леви Марк/в Каждый хочет любить.zip	zip
117	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Леви Марк/б Где ты.zip	zip
118	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Леви Марк/ж Те слова, что мы не сказали друг другу.zip	zip
119	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/н Конец.zip	zip
120	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/е Липовый лифт.zip	zip
121	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/к Скользский склон.zip	zip
122	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/б Змеиный зал.zip	zip
123	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/г Зловещая лесопилка.zip	zip
124	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/в Огромное окно.zip	zip
125	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/з Кошмарная клиника.zip	zip
126	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/д Изуверский интернат.zip	zip
127	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/ж Гадкий городишко.zip	zip
128	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/м Предпоследняя передряга.zip	zip
129	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/а Скверное начало.zip	zip
130	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/л Угрюмый грот.zip	zip
131	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Лемони Сникет/33 несчастья/и Кровожадный карнавал.zip	zip
132	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джеффри Форд/Портрет миссис Шарбук.zip	zip
133	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джеффри Форд/Клэй/в Запределье.zip	zip
134	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джеффри Форд/Клэй/б Меморанда.zip	zip
135	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джеффри Форд/Клэй/а Физиогномика.zip	zip
136	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джеффри Форд/Вихрь сновидений.zip	zip
137	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джеффри Форд/Девочка в стекле.zip	zip
138	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джеффри Форд/Год призраков.zip	zip
139	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джеффри Форд/Ночь в тропиках.zip	zip
140	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джеффри Форд/Империя мороженого.zip	zip
141	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джеффри Форд/Заклинание мантикоры.zip	zip
142	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Семёнова Мария/Волкодав/б  Право на поединок.zip	zip
143	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Семёнова Мария/Волкодав/а  Волкодав.zip	zip
144	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Семёнова Мария/Волкодав/г  Знамение пути.zip	zip
145	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Семёнова Мария/Волкодав/д  Самоцветные горы.zip	zip
146	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Семёнова Мария/Волкодав/в  Истовик-камень.zip	zip
147	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Семёнова Мария/Меч мертвых.zip	zip
148	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Семёнова Мария/Там, где лес не растет.zip	zip
149	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Семёнова Мария/Валькирия.zip	zip
150	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Семёнова Мария/Лебединая дорога.zip	zip
151	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Семёнова Мария/Бусый волк.zip	zip
152	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Майер Стефани/а  Сумерки.zip	zip
153	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Майер Стефани/г Ломая рассвет.zip	zip
154	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Майер Стефани/в  Затмение.zip	zip
155	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Майер Стефани/б  Новолуние.zip	zip
156	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Майер Стефани/д  Солнце полуночи.zip	zip
157	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Ролинг Джоан/б Гарри Поттер и Тайная комната.zip	zip
158	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Ролинг Джоан/а Гарри Поттер и Филосовский камень.zip	zip
159	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Ролинг Джоан/е Гарри Поттер и Принц-полукровка.zip	zip
160	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Ролинг Джоан/в Гарри Поттер и узник Азкабана.zip	zip
161	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Ролинг Джоан/г Гарри Поттер и Кубок Огня.zip	zip
162	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Ролинг Джоан/ж Гарри Поттер и Дары смерти.zip	zip
163	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Ролинг Джоан/д Гарри Поттер и Орден Феникса.zip	zip
164	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Марион Айзек/Тепло наших тел.zip	zip
165	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/е Наложницы Ненависти.fb2	fb2
166	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/о Ребус Галла.fb2	fb2
167	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/н Запах страха.fb2	fb2
168	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/б Командор войны.fb2	fb2
169	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/в Атака по правилам.fb2	fb2
170	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/п Паутина противостояния.fb2	fb2
171	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/з Тень Инквизитора.fb2	fb2
172	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/м День Дракона.fb2	fb2
173	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/л Царь горы.fb2	fb2
174	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/д И в аду есть герои.fb2	fb2
175	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/ж Куколка Последней Надежды .fb2	fb2
176	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/а Войны начинают неудачники.fb2	fb2
177	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/г Все оттенки черного.fb2	fb2
178	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/к Королевский крест.fb2	fb2
179	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/Тайный город/и Кафедра странников.fb2	fb2
180	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/La_Mystique_De_Moscou/б Занимательная механика.zip	zip
181	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/La_Mystique_De_Moscou/в Ручной Привод.zip	zip
182	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Панов Вадим/La_Mystique_De_Moscou/а Таганский перекресток.zip	zip
183	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Бьёрн Анастасия/Рин.zip	zip
184	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Мэйфейрские ведьмы/г Наследница ведьм.fb2	fb2
185	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Мэйфейрские ведьмы/е Талтос.fb2	fb2
186	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Мэйфейрские ведьмы/б Мейфейрские ведьмы.zip	zip
187	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Мэйфейрские ведьмы/д Лэшер.fb2	fb2
188	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Мэйфейрские ведьмы/в Невеста дьявола.fb2	fb2
189	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Мэйфейрские ведьмы/а Час ведьмовства.fb2	fb2
190	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Вампирские хроники/з Кровь и золото.fb2	fb2
191	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Вампирские хроники/б Вампир Лестат.fb2	fb2
192	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Вампирские хроники/а Интервью с вампиром.fb2	fb2
193	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Вампирские хроники/е Вампир Арман.fb2	fb2
194	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Вампирские хроники/г История похитителя тел.fb2	fb2
195	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Вампирские хроники/и Черная камея.fb2	fb2
196	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Вампирские хроники/в Царица проклятых.fb2	fb2
197	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Вампирские хроники/д Мемнох-дьявол.fb2	fb2
198	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Райс Энн/Вампирские хроники/ж Меррик.fb2	fb2
199	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Вероника Рот/Дивиргент/г Аллигент.zip	zip
200	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Вероника Рот/Дивиргент/в Инсургент .zip	zip
201	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Вероника Рот/Дивиргент/а Переход.zip	zip
202	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Вероника Рот/Дивиргент/б Дивергент.zip	zip
203	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Пехов Алексей/Страж/б Аутодафе.zip	zip
204	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Пехов Алексей/Страж/а Страж.zip	zip
205	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Пехов Алексей/Хроники Сиалы/г Змейка.fb2	fb2
206	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Пехов Алексей/Хроники Сиалы/в Вьюга теней.fb2	fb2
207	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Пехов Алексей/Хроники Сиалы/а Крадущийся в тени.fb2	fb2
208	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Пехов Алексей/Хроники Сиалы/б Джанга с тенями.fb2	fb2
209	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Пехов Алексей/Хроники Сиалы/д Начинается вьюга.fb2	fb2
210	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Пехов Алексей/Киндрэт/а Кровные братья.fb2	fb2
211	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Пехов Алексей/Киндрэт/б Колдун из клана смерти.fb2	fb2
212	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Пехов Алексей/Киндрэт/в Основатель.fb2	fb2
213	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Гейман Нил/Звездная пыль.zip	zip
214	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Гейман Нил/Коралина.zip	zip
215	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/д Заир.zip	zip
216	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/е Мактуб.zip	zip
217	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/г Ведьма с Портобелло.zip	zip
218	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/к Рождественская сказка.zip	zip
219	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/и Пятая гора.zip	zip
220	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/а Алхимик.zip	zip
221	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/в Дневник мага.zip	zip
222	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/з Победитель остается один.zip	zip
223	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/ж Одиннадцать минут.zip	zip
224	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/б Брида.zip	zip
225	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/И в день седьмой/а На берегу Рио-Пьедра.zip	zip
226	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/И в день седьмой/в Дьявол и сеньорита Прим.zip	zip
227	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коэльо Пауло/И в день седьмой/б Вероника решает умереть.zip	zip
228	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мид Райчел/Академия вампиров/б Ледяной укус.zip	zip
229	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мид Райчел/Академия вампиров/а Охотники и жертвы.zip	zip
230	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мид Райчел/Академия вампиров/е Последняя жертва.zip	zip
231	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мид Райчел/Академия вампиров/в Поцелуй тьмы.zip	zip
232	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мид Райчел/Академия вампиров/д Оковы для призрака.zip	zip
233	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мид Райчел/Академия вампиров/г Кровная клятва.zip	zip
234	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Мид Райчел/Академия вампиров/ж Возвращение домой.zip	zip
235	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хольбайн,  Деви/Нибелунги/а Кольцо нибелунгов.zip	zip
236	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хольбайн,  Деви/Нибелунги/б Месть нибелунгов.zip	zip
237	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Малышев Игорь/Лис.rtf	rtf
238	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Стокер Брэм/Дракула.zip	zip
239	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/о Пямять Света.zip	zip
240	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/з Путь Кинжалов.zip	zip
241	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/д Огни Небес.zip	zip
242	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/в Возрожденный Дракон.zip	zip
243	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/а Око Мира.zip	zip
244	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/б Великая Охота.zip	zip
245	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/а Новая Весна.zip	zip
246	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/н Башни Полуночи.zip	zip
247	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/е Властелин Хаоса.zip	zip
248	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/л Нож Сновидений.zip	zip
249	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/г Восходящая Тень.zip	zip
250	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/и Сердце Зимы.zip	zip
251	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/к Перекрестки Сумерек.zip	zip
252	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/ж Корона мечей.zip	zip
253	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Джордан Роберт/Колесо Времени/м Грядущая Буря.zip	zip
254	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Сапковский Анджей/Ведьмак/в  Кровь эльфов.zip	zip
255	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Сапковский Анджей/Ведьмак/б  Меч предназначения.zip	zip
256	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Сапковский Анджей/Ведьмак/д  Крещение огнем.zip	zip
257	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Сапковский Анджей/Ведьмак/г  Час презрения.zip	zip
258	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Сапковский Анджей/Ведьмак/е  Башня ласточки.zip	zip
259	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Сапковский Анджей/Ведьмак/а  Последнее желание.zip	zip
260	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Сапковский Анджей/Ведьмак/ж  Владычица озера.zip	zip
261	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Стюарт Мери/Мерлин/в  Последнее волшебство.zip	zip
262	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Стюарт Мери/Мерлин/б  Полые холмы.zip	zip
263	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Стюарт Мери/Мерлин/а  Хрустальный грот.zip	zip
264	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Стюарт Мери/Мерлин/г  День гнева.zip	zip
265	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Стюарт Мери/Мерлин/д  Принц и паломница.zip	zip
266	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коллинз Сьюзен/Голодные игры/в Сойка-пересмешница.zip	zip
267	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коллинз Сьюзен/Голодные игры/б Рождение огня.fb2	fb2
268	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Коллинз Сьюзен/Голодные игры/а Голодные игры.fb2	fb2
269	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Риордан Рик/б  Перси Джексон и море чудовищ.zip	zip
270	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Риордан Рик/д Перси Джексон и последний олимпиец.zip	zip
271	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Риордан Рик/в  Перси Джексон и проклятие титана.zip	zip
272	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Риордан Рик/а  Перси Джексон и похититель молний.zip	zip
273	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Риордан Рик/е Перси Джексон и олимпийцы. Секретные материалы.zip	zip
274	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Риордан Рик/г  Перси Джексон и лабиринт смерти.zip	zip
275	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Толкин Джон/б Братство кольца.zip	zip
276	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Толкин Джон/г Возвращение Короля.zip	zip
277	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Толкин Джон/в Две Крепости.zip	zip
278	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Толкин Джон/а Хоббит, или Туда и обратно.zip	zip
279	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/в  Сага о живых кораблях/а Волшебный корабль.zip	zip
280	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/в  Сага о живых кораблях/г Корабль судьбы 2.zip	zip
281	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/в  Сага о живых кораблях/в Корабль судьбы 1.zip	zip
282	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/в  Сага о живых кораблях/б Безумный корабль.zip	zip
283	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/е Заклинательницы ветров/а Полет гарпии.zip	zip
284	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/е Заклинательницы ветров/б Заклинательницы ветров.zip	zip
285	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/б Сага о Шуте и убийце/а Миссия Шута.zip	zip
286	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/б Сага о Шуте и убийце/б Золотой Шут.zip	zip
287	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/б Сага о Шуте и убийце/в Судьба Шута.zip	zip
288	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/а Сага о видящих/а Ученик убийцы.zip	zip
289	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/а Сага о видящих/в Странствия убийцы.zip	zip
290	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/а Сага о видящих/б Королевский убийца.zip	zip
291	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/д Сын солдата/в  Магия отступника.zip	zip
292	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/д Сын солдата/б  Лесной маг.zip	zip
293	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/д Сын солдата/а Дорога шамана.fb2	fb2
294	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/г Хроники дождевых чащоб/б Драконья Гавань.zip	zip
295	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/г Хроники дождевых чащоб/а Хранитель драконов.zip	zip
296	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/г Хроники дождевых чащоб/г. Кровь драконов.zip	zip
297	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Хобб Робин/г Хроники дождевых чащоб/в Город Драконов.zip	zip
298	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Кассандра Клэр/б Адские механизмы/а Механический ангел.zip	zip
299	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Кассандра Клэр/б Адские механизмы/в Механическая принцесса.zip	zip
300	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Кассандра Клэр/б Адские механизмы/б Механический принц.zip	zip
301	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Кассандра Клэр/Трилогия о Драко.zip	zip
302	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Кассандра Клэр/а Сумеречные охотники/б Город праха.zip	zip
303	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Кассандра Клэр/а Сумеречные охотники/г Город падших ангелов.zip	zip
304	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Кассандра Клэр/а Сумеречные охотники/д Город потерянных душ.zip	zip
305	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Кассандра Клэр/а Сумеречные охотники/в Город стекла.zip	zip
306	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Кассандра Клэр/а Сумеречные охотники/а Город костей.zip	zip
307	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Паолини Кристофер/Эрагон.zip	zip
308	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Харрис Шарлин/Сьюки Стакхауз/д Мертв как гвоздь.zip	zip
309	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Харрис Шарлин/Сьюки Стакхауз/г Мертвым сном.zip	zip
310	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Харрис Шарлин/Сьюки Стакхауз/а Мертвы, пока светло.zip	zip
311	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Харрис Шарлин/Сьюки Стакхауз/б Живые мертвецы в Далласе.zip	zip
312	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Харрис Шарлин/Сьюки Стакхауз/в Клуб мертвяков.zip	zip
313	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Харрис Шарлин/Сьюки Стакхауз/ж Сплошь мертвецы.zip	zip
314	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Харрис Шарлин/Сьюки Стакхауз/е Окончательно мертв.zip	zip
315	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Булгаков Михаил/Записки юного врача.zip	zip
316	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Булгаков Михаил/Собачье сердце.zip	zip
317	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фэнтези/Булгаков Михаил/Мастер и Маргарита.zip	zip
318	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Поэзия/Басё Мацуо/Хокку.zip	zip
319	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Поэзия/Лермонтов Михаил Юрьевич/Мцыри.zip	zip
320	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Поэзия/Шекспир Уильям/Король Лир.zip	zip
321	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Поэзия/Шекспир Уильям/Ромео и Джульетта.zip	zip
322	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Поэзия/Шекспир Уильям/Гамлет, принц датский.zip	zip
323	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Поэзия/Ростан Эдмонд/Сирано де Бержерак.zip	zip
324	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Филатов Леонид/Про Федота стрельца.fb2	fb2
325	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Филатов Леонид/Новый декамерон.fb2	fb2
326	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Гафт Валентин/Я постепенно познаю.fb2	fb2
327	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/ЧеширКо/а.  Дневник Домового.fb2	fb2
328	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/ЧеширКо/б. Дневник Домового. Рассказы с чердака.fb2	fb2
329	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Абгарян Наринэ/а. Манюня.fb2	fb2
330	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Абгарян Наринэ/б. Манюня. Юбилей Ба.fb2	fb2
331	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Абгарян Наринэ/в. Манюня пишет фантастический роман.fb2	fb2
332	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Экслер Алекс/Свадебное путешествие Лелика.fb2	fb2
333	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Экслер Алекс/Наши в Турции.fb2	fb2
334	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Экслер Алекс/Дневник Васи Пупкина.fb2	fb2
335	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Экслер Алекс/Записки кота Шашлыка.fb2	fb2
336	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Экслер Алекс/Записки невесты программиста.fb2	fb2
337	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Аверченко Аркадий/Избранные страницы.fb2	fb2
338	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Раневская Фаина/Анекдоты и тосты.fb2	fb2
339	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Раневская Фаина/Все афоризмы.fb2	fb2
340	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Раневская Фаина/Смех сквозь слезы.fb2	fb2
341	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Задорнов Михаил/Пиар во время чумы.fb2	fb2
342	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Задорнов Михаил/Большой концерт.fb2	fb2
343	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Задорнов Михаил/Я люблю Америку.fb2	fb2
344	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Задорнов Михаил/Умом Россию не поднять.fb2	fb2
345	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Задорнов Михаил/Придумано в СССР.fb2	fb2
346	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Задорнов Михаил/Записки усталого романтика.fb2	fb2
347	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Задорнов Михаил/Сила чисел.fb2	fb2
348	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/с. Дживс, вы - гений.fb2	fb2
349	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/ё. Дживс шевелит мозгами.fb2	fb2
350	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/л. Дживс и неумолимый.fb2	fb2
351	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/ч. Так держать, дживс.fb2	fb2
352	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/ж. Свадебные колокола отменются.fb2	fb2
353	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/е. Командует парадом Дживс.fb2	fb2
354	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/и. Товарищь Бинго.fb2	fb2
355	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/д. Тысяча благодарностей, Дживс.fb2	fb2
356	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/щ. Этот неподражаемый Дживс.fb2	fb2
357	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/г. Полный порядок, Дживс.fb2	fb2
358	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/х. Дживс уходит на каникулы.fb2	fb2
359	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/а. Бинго.Не везет в Гудвуде.fb2	fb2
360	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/р. Дживс и скользский тип.fb2	fb2
361	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/к. Без замены штрафом.fb2	fb2
362	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/б. Дживс готовит омлет.fb2	fb2
363	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/у. Шалости аристократов.fb2	fb2
364	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/ц. Дживс и песнь песней.fb2	fb2
365	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/о. Дживс и дух Рождества.fb2	fb2
366	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/з. Фамильная честь Вустеров.fb2	fb2
367	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/ш. Ваша взяла, Дживс.fb2	fb2
368	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/ф. Брачный сезон.fb2	fb2
369	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/м. Секретарь министра.fb2	fb2
370	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/в. Кодекс чести Вустеров.fb2	fb2
371	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/т. Вперед, Дживс.fb2	fb2
372	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/п. Не позвать ли нам Дживса.fb2	fb2
373	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юмор/Вудхауз Пэлем Грэнвилл/н. Находчивость Дживса.fb2	fb2
374	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мифы, легенды/Гомер/Илиада.zip	zip
375	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Старинная литература/Жуковский В.А/Илиада.zip	zip
376	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мифы, легенды/Гомер/Одиссея.zip	zip
377	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Старинная литература/Жуковский В.А/Одиссея.zip	zip
378	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мифы, легенды/Кун Николай/Легенды и мифы Древней Греции.zip	zip
379	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Стайн Роберт/Дом страха.zip	zip
380	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Апдайк Джон/Иствикские ведьмы.zip	zip
381	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Матесон Ричард/Я-легенда.zip	zip
382	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Город теней.fb2	fb2
383	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Пригоршня тьмы.fb2	fb2
384	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Тьма.fb2	fb2
385	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Черное дело.fb2	fb2
386	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Псы Вавилона.fb2	fb2
387	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Аватар бога.fb2	fb2
388	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Солнце мертвых.fb2	fb2
389	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Демоны ночи.fb2	fb2
390	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Дно разума.fb2	fb2
391	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Мара.fb2	fb2
392	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Карты Люцифера.fb2	fb2
393	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Девятая жизнь нечисти.fb2	fb2
394	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Код розенкрейцеров.fb2	fb2
395	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Бешеный.fb2	fb2
396	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Холодный человек.fb2	fb2
397	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Кровавый шабаш.fb2	fb2
398	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Серебряная пуля.fb2	fb2
399	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Скорпион нападает первым.fb2	fb2
400	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Атеев Алексей/Обреченный пророк.fb2	fb2
401	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кинг Стивен/Долгая прогулка.zip	zip
402	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кинг Стивен/Талисман.zip	zip
403	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кинг Стивен/Воспламеняющая взглядом.zip	zip
404	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кинг Стивен/Черный дом.zip	zip
405	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кинг Стивен/Лангольеры.zip	zip
406	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кинг Стивен/Армагеддон.zip	zip
407	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кинг Стивен/Куджо.zip	zip
408	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Невинность.fb2	fb2
409	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Безжалостный.fb2	fb2
410	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Психоделические дети.fb2	fb2
411	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Скорость.fb2	fb2
412	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Убивающие взглядом.fb2	fb2
413	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Звереныш (Вестник смерти).fb2	fb2
414	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Ключи к полуночи.fb2	fb2
415	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Подозреваемый (Муж).fb2	fb2
416	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Затаив дыхание.fb2	fb2
417	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Голос ночи.fb2	fb2
418	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Ледяная тюрьма.fb2	fb2
419	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Помеченный смертью.fb2	fb2
420	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Улица Теней, 77.fb2	fb2
421	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Слезы дракона.fb2	fb2
422	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Единственный выживший.fb2	fb2
423	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Молния (Покровитель).fb2	fb2
424	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Слуги сумерек (Сумерки).fb2	fb2
425	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Оборотень среди нас.fb2	fb2
426	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Джейн Хок/Кунц 1 Тихий уголок.fb2	fb2
427	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Джейн Хок/Кунц 2 Комната шепотов.fb2	fb2
428	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Звездная кровь.fb2	fb2
429	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Странный Томас/Кунц 06 Апокалипсис Томаса.fb2	fb2
430	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Странный Томас/Кунц 03 Брат Томас.fb2	fb2
431	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Странный Томас/Кунц 04 Ночь Томаса.fb2	fb2
432	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Странный Томас/Кунц 03 Демоны пустыни, или Брат Томас.fb2	fb2
433	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Странный Томас/Кунц 02 Казино смерти.fb2	fb2
434	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Странный Томас/Кунц 05 Интерлюдия Томаса (пер. Валерий Ледовской ).fb2	fb2
435	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Странный Томас/Кунц 07 Судьба Томаса, или Наперегонки со смертью.fb2	fb2
436	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Странный Томас/Кунц 05 Интерлюдия Томаса.fb2	fb2
437	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Странный Томас/Кунц 01 Странный Томас.fb2	fb2
438	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Полночь.fb2	fb2
439	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Видение.fb2	fb2
440	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Дьявольское семя (Помеченный смертью).fb2	fb2
441	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Нехорошее место.fb2	fb2
442	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Душа в лунном свете.fb2	fb2
443	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Эшли Белл.fb2	fb2
444	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Призрачные огни (Огни теней).fb2	fb2
445	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Невероятный дубликат.fb2	fb2
446	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Тьма под солнцем.fb2	fb2
447	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Предсказание.fb2	fb2
448	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Очарованный кровью.fb2	fb2
449	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Ложная память.fb2	fb2
450	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Славный парень.fb2	fb2
451	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Темные реки сердца.fb2	fb2
452	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Фантомы.fb2	fb2
453	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - При свете луны.fb2	fb2
454	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Чейз (Погоня).fb2	fb2
455	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Покровитель (Молния).fb2	fb2
456	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - До рая подать рукой.fb2	fb2
457	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Нехорошее место (пер. Вебер).fb2	fb2
458	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Шоу смерти (Вызов смерти).fb2	fb2
459	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Сумеречный взгляд.fb2	fb2
460	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Ночной кошмар (Властители душ).fb2	fb2
461	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Майк Такер/Кунц 1 Кровавый риск.fb2	fb2
462	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Дин Кунц/Кунц 2 Врата Ада.fb2	fb2
463	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Зимняя луна (Ад в наследство).fb2	fb2
464	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Кукольник.fb2	fb2
465	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Руки Олли.fb2	fb2
466	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Краем глаза.fb2	fb2
467	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Античеловек.fb2	fb2
468	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Лицо страха (По прозвищу «мясник»).fb2	fb2
469	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Ангелы-хранители.fb2	fb2
470	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Лунная бухта/Кунц 2 Скованный ночью.fb2	fb2
471	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Лунная бухта/Кунц 1 Живущий в ночи.fb2	fb2
472	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Дверь в декабрь.fb2	fb2
473	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Душа тьмы.fb2	fb2
474	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Маска.fb2	fb2
475	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Дом ужасов.fb2	fb2
476	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Гиблое место.fb2	fb2
477	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Черные реки сердца.fb2	fb2
478	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Незнакомцы (Красная луна).fb2	fb2
479	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Симфония тьмы.fb2	fb2
480	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Тик-так.fb2	fb2
481	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Провал в памяти.fb2	fb2
482	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Багровая ведьма.fb2	fb2
483	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Глаза тьмы.fb2	fb2
484	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Вторжение.fb2	fb2
485	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Лицо в зеркале.fb2	fb2
486	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Мутанты (Звездный поиск).fb2	fb2
487	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Дети бури.fb2	fb2
488	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Франкенштейн Дина Кунца/Кунц 1 Блудный сын.fb2	fb2
489	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Франкенштейн Дина Кунца/Кунц 3 Мертвый и живой.fb2	fb2
490	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Франкенштейн Дина Кунца/Кунц 5 Город мёртвых.fb2	fb2
491	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Франкенштейн Дина Кунца/Кунц 2 Город Ночи.fb2	fb2
492	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Франкенштейн Дина Кунца/Кунц 4 Потерянные души.fb2	fb2
493	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Город (сборник).fb2	fb2
494	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Наследие страха.fb2	fb2
495	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Дом Грома.fb2	fb2
496	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Отродье ночи (Шорохи).fb2	fb2
497	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Сошествие тьмы (Надвигается тьма).fb2	fb2
498	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Холодный огонь.fb2	fb2
499	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Путь из ада (Врата ада).fb2	fb2
500	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Ледяное пламя.fb2	fb2
501	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Логово (Прятки).fb2	fb2
502	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Мышка за стенкой скребется всю ночь.fb2	fb2
503	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Твое сердце принадлежит мне.fb2	fb2
504	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Мистер Убийца.fb2	fb2
505	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Неведомые дороги (сборник).fb2	fb2
506	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Ребенок-демон (Дитя Зверя).fb2	fb2
507	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Ткачев - Дин Кунц.fb2	fb2
508	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Самый темный вечер в году.fb2	fb2
509	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Исступление. Скорость (сборник).fb2	fb2
510	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Двенадцатая койка.fb2	fb2
511	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Ясновидящий.fb2	fb2
512	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Шорохи (Отродье ночи).fb2	fb2
513	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Вызов смерти.fb2	fb2
514	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Человек страха.fb2	fb2
515	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Что знает ночь.fb2	fb2
516	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ужасы и мистика/Кунц Дин/Кунц - Вестник смерти.fb2	fb2
517	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гаррисон Гарри/Крыса из нержавеющей стали/б  Крыса из нержавеющей стали призвана в армию.zip	zip
518	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гаррисон Гарри/Крыса из нержавеющей стали/з  Стальная крыса на манеже.zip	zip
519	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гаррисон Гарри/Крыса из нержавеющей стали/и  Крыса из нержавеющей стали спасает мир.zip	zip
520	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гаррисон Гарри/Крыса из нержавеющей стали/к  Стальная крыса отправляется в ад.zip	zip
521	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гаррисон Гарри/Крыса из нержавеющей стали/ж  Стальную крысу в президенты!.zip	zip
522	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гаррисон Гарри/Крыса из нержавеющей стали/г  Крыса из нержавеющей стали.zip	zip
523	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гаррисон Гарри/Крыса из нержавеющей стали/в  Стальная крыса поет блюз.zip	zip
524	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гаррисон Гарри/Крыса из нержавеющей стали/е  Ты нужен стальной крысе.zip	zip
525	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гаррисон Гарри/Крыса из нержавеющей стали/а  Крыса из нержавеющей стали появляется на свет.zip	zip
526	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гаррисон Гарри/Крыса из нержавеющей стали/д Месть крысы из нержавеющей стали.fb2	fb2
527	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гаррисон Гарри/Крыса из нержавеющей стали/л Новые приключения Стальной крысы.fb2	fb2
528	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Мартьянов Андрей/Вестники Времен/г  Законы заблуждений.zip	zip
529	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Мартьянов Андрей/Вестники Времен/в  Низвергатели легенд.zip	zip
530	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Мартьянов Андрей/Вестники Времен/е Время вестников.zip	zip
531	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Мартьянов Андрей/Вестники Времен/б  Творцы апокрифов.zip	zip
532	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Мартьянов Андрей/Вестники Времен/а  Вестники времен.zip	zip
533	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Мартьянов Андрей/Вестники Времен/д  Большая охота.zip	zip
534	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гофман Эрнст/Эликсиры Сатаны.zip	zip
535	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гофман Эрнст/Щелкунчик и мышиный король.zip	zip
536	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Гофман Эрнст/Житейские воззрения кота Мурра.zip	zip
537	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Стругацкие Аркадий и Борис/Понедельник начинается в субботу.zip	zip
538	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Стругацкие Аркадий и Борис/Улитка на склоне.zip	zip
539	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/Смерть и дева.zip	zip
540	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/Золотоглазые.zip	zip
541	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/Были они смуглые и золотоглазые.zip	zip
542	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/И камни заговорили.zip	zip
543	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/Призраки нового замка.zip	zip
544	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/Земляне.zip	zip
545	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/Детская площадка.zip	zip
546	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/Здесь водятся тигры.zip	zip
547	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/Надвигается беда.zip	zip
548	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/Канун всех святых.zip	zip
549	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/И всё-таки наш.zip	zip
550	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/451 градус по Фаренгейту.zip	zip
551	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/Марсианские хроники.zip	zip
552	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/Вино из одуванчиков.zip	zip
553	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Бредбери Рей/Лёд и пламя.zip	zip
554	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Глуховский Дмитрий/а  Метро 2033.zip	zip
555	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Глуховский Дмитрий/б Метро 2034.zip	zip
556	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Глуховский Дмитрий/Дневник ученого.zip	zip
557	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Этот бессмертный.zip	zip
558	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Мастер снов.zip	zip
559	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Имя мне - Легион/б Песнопевец.zip	zip
560	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Имя мне - Легион/а Проект Румоко.zip	zip
561	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Имя мне - Легион/в Возвращение палача.zip	zip
562	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Здесь водятся драконы.zip	zip
563	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Мир волшебника/б Одержимый магией.zip	zip
564	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Мир волшебника/а Подмененный.zip	zip
565	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Темное путешествие.zip	zip
566	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/История рыжего демона/а Принеси мне голову Прекрасного принца.zip	zip
567	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/История рыжего демона/б Если с Фаустом вам не повезло.zip	zip
568	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/История рыжего демона/в Пьеса должна продолжаться.zip	zip
569	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Фрэнк Сандау/в Свет Угрюмого.zip	zip
570	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Фрэнк Сандау/б Умереть в Италбаре.zip	zip
571	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Фрэнк Сандау/а Остров мертвых.zip	zip
572	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Хроники Амбера/д Владения Хаоса.zip	zip
573	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Хроники Амбера/г  Рука Оберона.zip	zip
574	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Хроники Амбера/б  Ружья Авалона.zip	zip
575	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Хроники Амбера/з  Знак Хаоса.zip	zip
576	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Хроники Амбера/и  Рыцарь Теней.zip	zip
577	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Хроники Амбера/к  Принц Хаоса.zip	zip
578	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Хроники Амбера/ж Кровь Амбера.zip	zip
579	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Хроники Амбера/в  Знак единорога.zip	zip
580	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Хроники Амбера/е   Карты судьбы.zip	zip
581	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Желязны Роджер/Хроники Амбера/а  Девять принцев Амбера.zip	zip
582	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Пристли Джон Бойнтон/31 июня.zip	zip
583	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Беляев Александр/Голова профессора Доуэля.zip	zip
584	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Беляев Александр/Ариэль.zip	zip
585	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Беляев Александр/Остров погибших кораблей.zip	zip
586	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Беляев Александр/Замок ведьм.zip	zip
587	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Беляев Александр/Человек-амфибия.zip	zip
588	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Хёнингский цикл/а Богадельня.zip	zip
589	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Хёнингский цикл/б Песни Петера Сьлядека.zip	zip
590	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Бездна голодных глаз/г Ничей дом.zip	zip
591	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Бездна голодных глаз/ж Мастер.zip	zip
592	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Бездна голодных глаз/д Пять минут взаймы.zip	zip
593	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Бездна голодных глаз/и Смех Диониса.zip	zip
594	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Бездна голодных глаз/к Последний.zip	zip
595	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Бездна голодных глаз/з Скидка на талант.zip	zip
596	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Бездна голодных глаз/а Восьмой круг подземки.zip	zip
597	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Бездна голодных глаз/л Разорванный круг.zip	zip
598	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Бездна голодных глаз/б Монстр.zip	zip
599	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Бездна голодных глаз/е Реквием по мечте.zip	zip
600	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Бездна голодных глаз/в Тигр.zip	zip
601	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Бездна голодных глаз/м Анабель-Ли.zip	zip
602	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Ойкумена/б Куколка.zip	zip
603	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Ойкумена/в Кукольных дел мастер.zip	zip
604	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Ойкумена/а Кукольник.zip	zip
605	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Герой должен быть один.zip	zip
606	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Сказки дедушки-вампира/б Сказки дедушки-вампира.zip	zip
607	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Сказки дедушки-вампира/е Nevermore.zip	zip
608	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Сказки дедушки-вампира/д Коган-варвар.zip	zip
609	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Сказки дедушки-вампира/ж Пророк.zip	zip
610	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Сказки дедушки-вампира/г Докладная записка.zip	zip
611	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Сказки дедушки-вампира/в Последнее допущение господа.zip	zip
612	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Сказки дедушки-вампира/а Кино до гроба.zip	zip
613	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Рассказы.zip	zip
614	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Олди Генри Лайон/Перекресток.zip	zip
615	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Лем Станислав/Магелланово Облако - royallib.ru.fb2.zip	zip
616	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фантастика/Уэллс Герберт/Машина времени.zip	zip
617	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Сервантес Мигель/Хитроумный Идальго Дон Кихот Ламанчский/Книга 2.zip	zip
618	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Сервантес Мигель/Хитроумный Идальго Дон Кихот Ламанчский/Книга 1.zip	zip
619	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Робертс Грегори Дэвид/Шантарам.zip	zip
620	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Голсуорси Джон/Сага о Форсайтах.zip	zip
621	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Голсуорси Джон/Конец главы.zip	zip
622	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Распэ Рудольф Эрих/Приключения барона Мюнхаузена.zip	zip
623	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Конан-Дойль Артур/Записки о Шерлоке Холмсе.zip	zip
624	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Конан-Дойль Артур/Затерянный мир.zip	zip
625	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Сабатини Рафаэль/Одиссея капитана Блада.zip	zip
626	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Кизи Кен/Над кукушкиным гнездом.zip	zip
627	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Дефо Даниэль/Жизнь и удивительные приключения Робинзона Крузо.zip	zip
628	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Диккенс Чарльз/Рождественская песнь.zip	zip
629	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Диккенс Чарльз/Домби и сын.zip	zip
630	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Воронкова Любовь/Александр Македонский/а Сын Зевса.zip	zip
631	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Воронкова Любовь/Александр Македонский/б В глуби веков.zip	zip
632	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Стивенсон Роберт Льюис/Приключения принца Флоризеля/а Клуб самоубийц.zip	zip
633	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Стивенсон Роберт Льюис/Приключения принца Флоризеля/б Алмаз Раджи.zip	zip
634	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Стивенсон Роберт Льюис/Странная история доктора Джекила и мистера Хайда.zip	zip
635	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Стивенсон Роберт Льюис/Баллады.zip	zip
636	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Стивенсон Роберт Льюис/Остров сокровищ.zip	zip
637	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Брусникин Анатолий/Девятный Спас.zip	zip
638	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Дюма Александр/а Три мушкетера.zip	zip
639	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Дюма Александр/Асканио.zip	zip
640	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Дюма Александр/Граф Монте-Кристо.zip	zip
641	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Гюго Виктор/Человек, который смеется.zip	zip
642	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Гюго Виктор/Отверженные.zip	zip
643	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Гюго Виктор/Собор Парижской Богоматери.zip	zip
644	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Лондон Джек/Белый клык.zip	zip
645	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Алексеев Сергей/Кольцо принцессы.zip	zip
646	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Алексеев Сергей/Покаяние пророков.zip	zip
647	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Алексеев Сергей/Сокровища Валькирии/г  Звездные раны.zip	zip
648	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Алексеев Сергей/Сокровища Валькирии/в  Земля сияющей власти.zip	zip
649	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Алексеев Сергей/Сокровища Валькирии/д  Хранитель Силы.zip	zip
650	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Алексеев Сергей/Сокровища Валькирии/е  Правда и вымысел.zip	zip
651	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Алексеев Сергей/Сокровища Валькирии/а  Стоящий у Солнца.zip	zip
652	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Алексеев Сергей/Сокровища Валькирии/б  Страга Севера.zip	zip
653	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Алексеев Сергей/Молчание пирамид.zip	zip
654	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Твен Марк/Приключения Тома Сойера.zip	zip
655	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Твен Марк/Принц и нищий.zip	zip
656	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Твен Марк/Янки из Коннектикута при дворе короля Артура.zip	zip
657	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Ян Василий Григорьевич/Нашествие монголов/с. К последнему морю.zip	zip
658	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Ян Василий Григорьевич/Нашествие монголов/а. Чингисхан.zip	zip
659	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Ян Василий Григорьевич/Нашествие монголов/б. Батый.zip	zip
660	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Ян Василий Григорьевич/Юность полководца.zip	zip
661	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Скотт Вальтер/Квентин Дорвард.zip	zip
662	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Скотт Вальтер/Айвенго.zip	zip
663	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Дрюон Морис/Проклятые короли/в  Яд и корона.zip	zip
664	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Дрюон Морис/Проклятые короли/а  Железный король.zip	zip
665	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Дрюон Морис/Проклятые короли/б  Узница Шато-Гайара.zip	zip
666	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Дрюон Морис/Проклятые короли/г  Негоже лилиям прясть.zip	zip
667	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Дрюон Морис/Проклятые короли/е  Лилия и лев.zip	zip
668	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Дрюон Морис/Проклятые короли/д  Французская волчица.zip	zip
669	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Дрюон Морис/Проклятые короли/ж  Когда король губит Францию.zip	zip
670	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Корнуэлл Бернард/Саксонские хроники/з Пустой Трон.zip	zip
671	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Корнуэлл Бернард/Саксонские хроники/ж Языческий лорд.zip	zip
672	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Корнуэлл Бернард/Саксонские хроники/е Смерть королей.zip	zip
673	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Корнуэлл Бернард/Саксонские хроники/б Бледный всадник.zip	zip
674	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Корнуэлл Бернард/Саксонские хроники/а Последнее королевство.zip	zip
675	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Корнуэлл Бернард/Саксонские хроники/г Песнь небесного меча.zip	zip
676	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Корнуэлл Бернард/Саксонские хроники/д Горящая земля.zip	zip
677	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Корнуэлл Бернард/Саксонские хроники/в Властелин Севера.zip	zip
678	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Джером Джером Клапка/Трое на четырех колесах.zip	zip
679	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Джером Джером Клапка/Трое в лодке (не считая собаки).zip	zip
680	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Свифт Джонатан/Путешествия Гулливера.zip	zip
681	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Буссенар Луи Анри/Похитители бриллиантов.zip	zip
682	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Хаггард Генри Райдер/Прекрасная Маргарет.zip	zip
683	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Хаггард Генри Райдер/Копи царя Соломона.zip	zip
684	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Хаггард Генри Райдер/Дочь Монтесумы.zip	zip
685	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Верн Жюль Габриэль/Дети капитана Гранта.zip	zip
686	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Верн Жюль Габриэль/Двадцать тысяч лье под водой.zip	zip
687	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Верн Жюль Габриэль/Таинственный остров.zip	zip
688	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения/Верн Жюль Габриэль/Путешествие к центру Земли.zip	zip
689	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Старинная литература/Алигьери Данте/Божественная комедия.zip	zip
690	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Старинная литература/Бокаччо Джованни/Декамерон.zip	zip
691	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Лоренс Ким/Праздник для двоих.zip	zip
692	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Солнце Ирина/Случайности не случайны.fb2	fb2
693	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Ахерн Сесилия/Я люблю тебя.zip	zip
694	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Ахерн Сесилия/Посмотри на меня.zip	zip
695	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Ахерн Сесилия/Время моей Жизни.zip	zip
696	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Ахерн Сесилия/Не верю. Не надеюсь. Люблю.zip	zip
697	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Ахерн Сесилия/Там, где ты.zip	zip
698	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Ахерн Сесилия/Волшебный дневник.zip	zip
699	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Ахерн Сесилия/Люблю твои воспоминания.zip	zip
700	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Ахерн Сесилия/Там, где заканчивается радуга.zip	zip
701	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Ахерн Сесилия/Подарок.zip	zip
702	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Мопассан/г Милый друг.zip	zip
703	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Мопассан/в Жизнь.zip	zip
704	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Мопассан/е На воде.zip	zip
705	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Мопассан/д Монт-Ориоль.zip	zip
706	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Мопассан/и Пьер и Жан.zip	zip
707	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Мопассан/б Доктор Ираклий Глосс.zip	zip
708	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Мопассан/з Пышка.zip	zip
709	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Мопассан/а Анжелюс.zip	zip
710	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Бронте Шарлотта/Джен Эйр.zip	zip
711	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Гарди Томас/Тэсс из рода Д`Эрбервиллей.fb2.zip	zip
712	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Кокс Мэгги/Секреты обольщения.zip	zip
713	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Джеймс Элоиза/Четыре сестры/г. Укрощение герцога.fb2.zip	zip
714	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Джеймс Элоиза/Четыре сестры/д. Вкус блаженства.fb2.zip	zip
715	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Джеймс Элоиза/Четыре сестры/а. Много шума из-за невесты.fb2.zip	zip
716	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Джеймс Элоиза/Четыре сестры/в. Неприличные занятия.fb2.zip	zip
717	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Джеймс Элоиза/Четыре сестры/б. Супруг для леди.fb2.zip	zip
718	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Беллами Кэтрин/Пропавшее кольцо.zip	zip
719	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Остин Джейн/Мэнсфильд-парк.zip	zip
720	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Остин Джейн/Гордость и предубеждение.zip	zip
721	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Остин Джейн/Нортенгерское аббатство.zip	zip
722	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Остин Джейн/Доводы рассудка.zip	zip
723	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Остин Джейн/Разум и чувства.zip	zip
724	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Остин Джейн/Эмма.zip	zip
725	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Маккалоу Колин/Поющие в терновнике.zip	zip
726	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Уэбб Кэтрин/Наследиe.fb2.zip	zip
727	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Уэбб Кэтрин/Незаконнорожденная.fb2.zip	zip
728	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Спир Флора/Гимн Рождества.zip	zip
729	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Делакорт Шона/Раздели со мной жизнь.zip	zip
730	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Грэхем Линн/Лук Амура.zip	zip
731	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Макнот Джудит/Битва желаний.zip	zip
732	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Макнот Джудит/Что я без тебя.zip	zip
733	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Робертс Нора/Моя любимая ошибка.fb2	fb2
734	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Коэльо Пауло/Вероника решает умереть.fb2.zip	zip
735	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Томпсон Доун/Властелин воды.zip	zip
736	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Голден Артур/Мемуары гейши.zip	zip
737	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Рэдклифф Анна/Итальянец.fb2.zip	zip
738	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Рэдклифф Анна/Роман в лесу.fb2.zip	zip
739	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Рэдклифф Анна/Удольфские тайны.fb2.zip	zip
740	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Деверо Джуд/Рыцарь.zip	zip
741	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Деверо Джуд/Первые впечатления.zip	zip
742	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Гюнтекин Решад Нури/Птичка певчая.zip	zip
743	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Романы/Меттоуз Дженнифер/Заповедник чувств.zip	zip
744	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/2  Богиня прайм-тайма.zip	zip
745	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/5  Дом-фантом в приданое.zip	zip
746	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/24 На одном дыхании.zip	zip
747	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/22 Хроника гнусных времен.zip	zip
748	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/7  Запасной инстинкт.zip	zip
749	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/15 Персональный ангел.zip	zip
750	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/23 Всегда говори  - всегда.zip	zip
751	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/16 Подруга особого назначения.zip	zip
752	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/4 Гений пустого места.zip	zip
753	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/20 Саквояж со светлым будущим.zip	zip
754	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/11 Одна тень на двоих.zip	zip
755	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/27 Колодец забытых желаний.zip	zip
756	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/6  Закон обратного волшебства.zip	zip
757	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/26 Жизнь, по слухам, одна.zip	zip
758	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/9  Мой генерал.zip	zip
759	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/1  Близкие люди.zip	zip
760	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/8  Миф об идеальном мужчине.zip	zip
761	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/18 Пять шагов по облакам.zip	zip
762	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/3  Большон зло и мелкие пакости.zip	zip
763	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/12 Олигарх с Большой Медведицы.zip	zip
764	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/25 Там, где нас нет.zip	zip
765	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/10 Мой личный враг.zip	zip
766	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/13 Отель последней надежды.zip	zip
767	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/17 Пороки и их поклонники.zip	zip
768	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/12 От первого до последнего слова.zip	zip
769	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/21 Седьмое небо.zip	zip
770	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/14 Первое правило королевы.zip	zip
771	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Устинова Татьяна/19 Развод и девичья фамилия.zip	zip
772	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/м Весь мир - театр.zip	zip
773	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/д Особые приключения. Пиковый валет.zip	zip
774	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/и Любовник смерти.zip	zip
775	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/в Левиафан.zip	zip
776	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/ка Алмазная колесница.zip	zip
777	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/н Черный город.zip	zip
778	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/з Любовница смерти.zip	zip
779	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/ё Статский советник.zip	zip
780	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/е Особые приключения. Декоратор.zip	zip
781	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/л Нефритовые четки.zip	zip
782	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/б Турецкий гамбит.zip	zip
783	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/г Смерть Ахиллеса.zip	zip
784	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/ж Коронация, или Последний из романов.zip	zip
785	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Акунин Борис/Приключения Эраста Фандорина/а Азазель.zip	zip
786	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Дом одиноких сердец.zip	zip
787	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Макар Илюшин и Сергей Бабкин/к Манускрипт дьявола.zip	zip
788	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Макар Илюшин и Сергей Бабкин/д Рыцарь нашего времени.zip	zip
789	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Макар Илюшин и Сергей Бабкин/л Золушка и дракон.zip	zip
790	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Макар Илюшин и Сергей Бабкин/м Комната старинных ключей.zip	zip
791	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Макар Илюшин и Сергей Бабкин/и Дудочка крысолова.zip	zip
792	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Макар Илюшин и Сергей Бабкин/а Знак истинного пути.zip	zip
793	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Макар Илюшин и Сергей Бабкин/в Темная сторона души.zip	zip
794	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Макар Илюшин и Сергей Бабкин/з Улыбка пересмешника.zip	zip
795	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Макар Илюшин и Сергей Бабкин/г Водоворот чужих желаний.zip	zip
796	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Макар Илюшин и Сергей Бабкин/е Призрак в кривом зеркале.fb2	fb2
797	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Макар Илюшин и Сергей Бабкин/б Остров сбывшейся мечты.zip	zip
798	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Макар Илюшин и Сергей Бабкин/ж Танцы марионеток.fb2	fb2
799	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Жизнь под чужим солнцем.zip	zip
800	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Мужская логика 8 марта.zip	zip
801	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Убийственная библиотека.zip	zip
802	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Время собирать камни.zip	zip
803	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Михалкова Елена/Черная кошка в белой комнате.zip	zip
804	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Артефакт/1 Сокровище Китеж-града.zip	zip
805	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Артефакт/3 Кинжал Зигфрида.zip	zip
806	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Артефакт/2 Золотой Идол Огнебога.zip	zip
807	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Рассказы/3 Колье от Лалик.zip	zip
808	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Рассказы/2 Гороскоп.zip	zip
809	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Рассказы/6 Месопотамский демон.zip	zip
810	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Рассказы/5 Медальон.zip	zip
811	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Рассказы/1 Вино из мандрагоры.zip	zip
812	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Рассказы/4 Кольцо с коралловой эмалью.zip	zip
813	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Рассказы/7 Танец индийской богини.zip	zip
814	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Игра с цветами смерти/4 Черная роза.zip	zip
815	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Игра с цветами смерти/3 Зеленый омут.zip	zip
816	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Игра с цветами смерти/2 Иллюзии красного.zip	zip
817	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Игра с цветами смерти/1 Золотые нити.zip	zip
818	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Сады Кассандры/2 Кольцо Гекаты.zip	zip
819	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Сады Кассандры/1 Пятерка мечей.zip	zip
820	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Всеслав и Ева/1 Третье рождение Феникса.zip	zip
821	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Всеслав и Ева/8 Испанские шахматы.zip	zip
822	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Всеслав и Ева/4 Московский лабиринт Минотавра.zip	zip
823	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Всеслав и Ева/3 Шарада Шекспира.zip	zip
824	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Всеслав и Ева/5 Печать фараона.zip	zip
825	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Всеслав и Ева/9 Венера Челлини.zip	zip
826	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Всеслав и Ева/7 Этрусское зеркало.zip	zip
827	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Всеслав и Ева/6 Черная жемчужина императора.zip	zip
828	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Всеслав и Ева/2 Яд древней богини.zip	zip
829	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Астра Ельцова/8 Звезда Вавилона.zip	zip
830	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Астра Ельцова/5 Часы королевского астролога.zip	zip
831	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Астра Ельцова/1 Магия венецианского стекла.zip	zip
832	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Астра Ельцова/2 Загадки последнего сфинкса.zip	zip
833	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Астра Ельцова/7 Золото скифов.zip	zip
834	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Астра Ельцова/6 Ларец Лунной Девы.zip	zip
835	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Случайный гость.zip	zip
836	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Солнцева Наталья/Монета желаний.zip	zip
837	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/The Body in the Library.zip	zip
838	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Десять негритят.zip	zip
839	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/30 Смерть Мисс Мак-Джинти.zip	zip
840	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/31 После похорон.zip	zip
841	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/29 Берег удачи.zip	zip
842	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/18 Невероятная кража.zip	zip
843	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/35 Приключения рождественского пудинга.zip	zip
844	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/20 Родосский треугольник.zip	zip
845	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/37 Третья девушка.zip	zip
846	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/13 Убийство в Месопотамии.zip	zip
847	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/8 Смерть лорда Эджвера.zip	zip
848	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/24 Печальный кипарис.zip	zip
849	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/12 Убийство по алфавиту.zip	zip
850	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/3 Пуаро ведет следствие.zip	zip
851	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/32 Хикори, дикори, док....zip	zip
852	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/40 Ранние дела Пуаро.zip	zip
853	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/42 Убийство в Каретном ряду.zip	zip
854	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/27 Лощина.zip	zip
855	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/28 Подвиги Геракла.zip	zip
856	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/26 Пять поросят.zip	zip
857	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/17 Убийство в проходном дворе.zip	zip
858	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/19 Разбитое зеркало.zip	zip
859	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/36 Часы.zip	zip
860	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/6 Тайна Голубого поезда.zip	zip
861	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/38 Вечеринка в Хэллоуин.zip	zip
862	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/39 Слоны умеют помнить.zip	zip
863	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/33 Конец человеческой глупости.zip	zip
864	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/7 Загадка Эндхауза.zip	zip
865	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/2 Убийство на поле для гольфа.zip	zip
866	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/10 Убийство в Восточном экспрессе.zip	zip
867	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/1 Таинственное происшествие в Стайлз.zip	zip
868	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/41 Занавес.zip	zip
869	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/34 Кошка среди голубей.zip	zip
870	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/14 Карты на стол.zip	zip
871	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/4 Убийство Роджера Экройда.zip	zip
872	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/9 Трагедия в трех актах.zip	zip
873	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/5 Большая четверка.zip	zip
874	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/25 Зло под солнцем.zip	zip
875	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/21 Свидание со смертью.zip	zip
876	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/23 Раз, два - пряжку застегни.zip	zip
877	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/15 Смерть на Ниле.zip	zip
878	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/22 Рождество Эркюля Пуаро.zip	zip
879	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/16 Безмолвный свидетель.zip	zip
880	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Кристи Агата/Эркюль Пуаро/11 Смерть в облаках.zip	zip
881	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Симеон Жорж/Желтый пес - royallib.ru.fb2.zip	zip
882	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Коллинз Уилки/Лунный камень.zip	zip
883	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Полякова Татьяна/Испанская легенда.zip	zip
884	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Полякова Татьяна/Как бы не так.zip	zip
885	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Полякова Татьяна/Честное имя.zip	zip
886	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Полякова Татьяна/Я-ваши неприятности.zip	zip
887	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Полякова Татьяна/Человек, подаривший ей собаку.zip	zip
888	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Даже ведьмы умеют плакать.zip	zip
889	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Солнце светит не всем.zip	zip
890	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Золотая дева.zip	zip
891	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Вояж с морским дьяволом.zip	zip
892	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Парфюмер звонит первым.zip	zip
893	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Второй раз не воскреснешь.zip	zip
894	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Пальмы, солнце, алый снег.zip	zip
895	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Красивые, дерзкие, злые.zip	zip
896	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/В Питер вернутся не все.zip	zip
897	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Осколки великой мечты.zip	zip
898	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Эксклюзивный грех.zip	zip
899	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Внебрачная дочь продюсера.zip	zip
900	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Через время, через океан.zip	zip
901	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Отпуск на тот свет.zip	zip
902	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Коллекция страхов прет-а-порте.zip	zip
903	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Я тебя никогда не забуду.zip	zip
904	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Ревность волхвов.zip	zip
905	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/Рецепт идеальной мечты.zip	zip
906	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Литвиновы Анна и Сергей/У судьбы другое имя.zip	zip
907	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Хмелевская Иоанна/Кот в мешке.zip	zip
908	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Хмелевская Иоанна/По ту сторону барьера.zip	zip
909	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Хмелевская Иоанна/Убийственное меню.zip	zip
910	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Хмелевская Иоанна/Колодцы предков.zip	zip
911	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детектив/Хмелевская Иоанна/Закон постоянного невезения.zip	zip
301	2021-03-24 19:59:10.916997+00	2021-03-24 19:59:10.916997+00	Фэнтези/Кассандра Клэр/Трилогия о Драко.fb2	fb2
\.


--
-- Data for Name: books; Type: TABLE DATA; Schema: public; Owner: kurush
--

COPY public.books (id, created_at, updated_at, title, skin_image, description, genres) FROM stdin;
4	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Страта	\N	Васи́ль Влади́мирович Бы́ков (белор. Васіль Уладзіміравіч  Быкаў; 19 июня 1924, дер. Бычки Ушачского района Витебской области[5][6] — 22 июня 2003, Боровляны) — советский и белорусский писатель, общественный деятель, депутат Верховного Совета БССР 9—11 созывов, участник Великой Отечественной войны. Член Союза писателей СССР.\n	{Фэнтези}
5	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кот без дураков	\N	Впервые опубликована на английском языке в 1989 году в Великобритании. Написана в форме мини-энциклопедии, от имени вымышленного «Движения в защиту настоящих котов» (англ. A Campaign For Real Cat).\nВ юмористической форме описаны преимущества «настоящих», то есть беспородных, непослушных и капризных котов. Под маской ироничности видна любовь автора к животным.\n	{Фэнтези}
3	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Темная сторона Солнца	\N	\N	{Фэнтези}
6	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Люди Ковра	\N	\N	{Фэнтези}
8	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мрачный Жнец	\N	\N	{Фэнтези}
9	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Санта-Хрякус	\N	Двадцатая книга из цикла «Плоский мир», четвёртая книга подцикла о Смерти и его внучке Сьюзан.\n	{Фэнтези}
7	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Благие знамения	\N	«Благи́е зна́мения»[1] (англ. Good Omens, в других переводах — «Добрые предзнаменования») — роман английских писателей Терри Пратчетта и Нила Геймана в жанре юмористического городского фэнтези. Для Нила Геймана книга стала первым крупным литературным произведением. Роман, выдержанный в тонкой манере английского юмора, рассказывает об ангеле и демоне, пытающихся предотвратить библейский Апокалипсис. Книга содержит большое количество аллюзий, цитат и отсылок к современной массовой культуре, в особенности к фильму «Омен». Русский перевод книги вышел в ноябре 2012 года в издательстве «Эксмо», переводчик — Маргарита Юркан[2]. Также существуют переводы Вадима Филиппова и Виктора Вербицкого. Российское издание книги вышло в чёрной обложке серии «под Терри Пратчетта»[3].\n	{Фэнтези}
10	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вертушки ночи (рассказ)	\N	«Де́ти но́чи» (англ. «The Children of the Night») — рассказ Роберта Говарда, из фэнтезийного «Пиктского цикла» и мистического литературного сериала «Конрад и Кирован». Написан в октябре 1930 года[2]. Опубликован в 1931 году в американском журнале фантастики Weird Tales. Входит в большую межавторскую антологию «Мифы Ктулху» (первый рассказ Говарда в сеттинге Лавкрафта). В этом рассказе впервые упомянуты два известных персонажа Говарда — профессор Джон Кирован и легендарный исследователь оккультизма фон Юнцт, автор эзотерической книги «Unaussprechlichen Kulten».\n	{Фэнтези}
13	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Роковая музыка	\N	Шестнадцатая книга из цикла «Плоский мир», третья книга подцикла о Смерти и его внучке Сьюзан.\n	{Фэнтези}
14	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вор Времени	\N	Двадцать шестая книга из серии цикла «Плоский мир», пятая книга из цикла о Смерти.\n	{Фэнтези}
11	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Смерть и Что Случается После (рассказ)	\N	«Плоский мир» (англ. Discworld — букв. «Мир-диск») — серия книг Терри Пратчетта, написанных в жанре юмористического фэнтези. Серия содержит более 40 книг и ориентирована преимущественно на взрослых, хотя четыре книги были выпущены на рынок как книги для детей или подростков[1]. Первые книги серии являются пародиями на общепринятое в жанре фэнтези, но в более поздних книгах писатель рассматривает проблемы реального мира[1]. \nБлагодаря «Плоскому миру» Пратчетт является одним из наиболее популярных авторов Великобритании.\n	{Фэнтези}
12	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мор, ученик Смерти	\N	\N	{Фэнтези}
16	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пехотная баллада	\N	\N	{Фэнтези}
38	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Поваренная книга Нянюшки Огг	\N	\N	{Фэнтези}
19	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мелкие боги	\N	\N	{Фэнтези}
20	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Движущиеся картинки	\N	\N	{Фэнтези}
21	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Интересные времена	\N	Семнадцатая книга из цикла «Плоский мир», пятая книга из цикла о волшебнике Ринсвинде.\n	{Фэнтези}
24	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Последний континент	\N	«Последний континент» (англ. The Last Continent) — юмористическое фэнтези английского писателя Терри Пратчетта, написано в 1998 году.\n	{Фэнтези}
27	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Последний герой	\N	«Последний герой. Сказание о Плоском мире» (англ. The Last Hero. A Discworld Fable) — юмористическое фэнтези английского писателя Терри Пратчетта, написано в 2001 году.\n	{Фэнтези}
15	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пирамиды	\N	\N	{Фэнтези}
29	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Наука Плоского мира. Книга 2. Глобус	\N	\N	{Фэнтези}
30	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Наука Плоского Мира	\N	\N	{Фэнтези}
18	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Удивительный Морис и его ученые грызуны (ЛП)	\N	Двадцать восьмая книга из серии цикла «Плоский мир», шестая книга вне циклов.\n	{Фэнтези}
31	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Наука Плоского Мира III. Часы Дарвина (ЛП)	\N	\N	{Фэнтези}
32	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Carpe Jugulum. Хватай за горло!	\N	Двадцать третья книга из цикла «Плоский мир», шестая книга подцикла о ведьмах.\n	{Фэнтези}
33	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Маскарад	\N	«Маскара́д» — драма Лермонтова в четырёх действиях, в стихах. Главным героем её является наделённый мятежным духом и умом дворянин Евгений Арбенин.\n	{Фэнтези}
22	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Эрик, а также Ночная стража, ведьмы и Коэн-Варвар	\N	\N	{Фэнтези}
23	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Незримые Академики	\N	Тридцать седьмая книга цикла «Плоский мир», девятая книга вне циклов.\n	{Фэнтези}
34	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Тиффани Эйкинг 1. Вольный народец (ЛП)	\N	Тридцатая книга из серии цикла «Плоский мир», первая книга из цикла о Тиффани Болен.\n	{Фэнтези}
25	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Цвет волшебства	\N	«Цвет волшебства́» (англ. The Colour of Magic) — юмористическое фэнтези известного английского писателя Терри Пратчетта, опубликовано в 1983 году (хотя написано было ещё в 1960-х гг). Первая книга из цикла «Плоский мир», включающего 41 произведение.\n	{Фэнтези}
26	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Посох и шляпа	\N	\N	{Фэнтези}
41	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дамы и Господа	\N	\N	{Фэнтези}
28	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Безумная звезда	\N	\N	{Фэнтези}
42	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вещие сестрички	\N	Шестая из серии цикла «Плоский мир», вторая книга подцикла о ведьмах.\n	{Фэнтези}
43	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ночная стража	\N	«Ночная стража» (англ. Night Watch) — юмористическое фэнтези известного английского писателя Терри Пратчетта, написано в 2002 году.\nОбложка британского издания книги, нарисованная Полом Кидби, является аллюзией на картину Рембрандта «Ночной дозор».\n	{Фэнтези}
44	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	К оружию! К оружию!	\N	Пятнадцатая книга из цикла «Плоский мир», вторая книга подцикла о Страже.\n	{Фэнтези}
45	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дело табак	\N	«Дело табак» (англ. Snuff) — фантастический роман английского писателя Терри Пратчетта, тридцать девятая книга из цикла «Плоский мир»[4], восьмая и последняя книга из цикла о Городской страже. На русском языке роман впервые был опубликован издательством «Эксмо» 1 августа 2014 года в переводе В. Сергеевой под названием «Дело табак»[5][6], также существуют неофициальные переводы под названием «Понюшка»[7] и «Разрушение»[1].\n	{Фэнтези}
47	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пятый элефант	\N	Двадцать четвёртая книга цикла «Плоский мир», пятая книга из цикла о Страже.\n	{Фэнтези}
48	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Стража! Стража!	\N	Восьмая книга из цикла «Плоский мир», первая книга подцикла о  Страже.\n	{Фэнтези}
35	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Тиффани Эйкинг 3. Зимних Дел Мастер (ЛП)	\N	Тридцать пятая книга цикла «Плоский мир», третья книга из цикла о Тиффани Болен.\n	{Фэнтези}
36	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Творцы заклинаний	\N	\N	{Фэнтези}
37	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Тиффани Эйкинг 2. Шляпа, полная небес… (ЛП)	\N	Тридцать вторая книга цикла «Плоский мир», вторая книга из цикла о Тиффани.\n	{Фэнтези}
50	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ноги из глины	\N	Девятнадцатая книга из цикла «Плоский мир», третья книга подцикла о страже.\n	{Фэнтези}
54	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Крылья	\N	\N	{Фэнтези}
78	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Простые волшебные вещи	\N	\N	{Фэнтези}
57	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Джонни и бомба	\N	\N	{Фэнтези}
58	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Джонни и мертвецы	\N	\N	{Фэнтези}
39	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Тиффани Эйкинг 4. Я надену чёрное (ЛП)	\N	Тридцать восьмая книга цикла «Плоский мир», четвёртая книга из цикла о Тиффани Болен.\n	{Фэнтези}
60	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Бесконечная земля	\N	Идея о цепочке параллельных миров пришла Терри Пратчетту более 25 лет назад, но, в связи с работой над циклом «Плоский мир», замысел не был реализован[4].\n	{Фэнтези}
293	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дорога шамана	\N	\N	{Фэнтези}
61	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Бесконечная война	\N	«Бесконечная война» или «Вечная Война» (англ. The Forever War, 1974) — самый известный роман американского писателя Джо Холдемана. Холдеман принимал участие в войне во Вьетнаме и был ранен, эти события оказали большое влияние на его творчество. Антимилитаристская книга является своеобразным ответом на «Звёздный десант» Роберта Хайнлайна.\n	{Фэнтези}
69	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ключ из желтого металла	\N	\N	{Фэнтези}
70	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Лабиринт	\N	 «Лабиринт Пресс»  — российское издательство, основанное в 1991 году. Специализируется на издании детской литературы.\n	{Фэнтези}
72	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Наваждения	\N	\n«Наваждения» — пятый (четвертый в самых ранних изданиях) том фэнтези-сериала Лабиринты Ехо Макса Фрая. Книга содержит две повести, повествующие о приключениях сэра Макса в мире Ехо.\n	{Фэнтези}
46	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Шмяк!	\N	«Шмяк!», «Бум!», «Бац!» (англ. Thud!)[1] — фэнтези известного английского писателя Терри Пратчетта, написано в 2005 году. Впервые на русском языке было издано издательством «Эксмо» в декабре 2013 года[2], также есть неофициальные переводы.\n	{Фэнтези}
73	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Лабиринт Мёнина	\N	Лабиринт Мёнина — 8-й и последний том фэнтези-сериала Лабиринты Ехо авторства Макса Фрая. Этот том выходил только во 2-м издании.\n	{Фэнтези}
74	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Болтливый мертвец	\N	Болтливый мертвец — 6-й (в первом издании 7-й) том фэнтези-сериала Лабиринты Ехо авторства Макса Фрая.\n	{Фэнтези}
49	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Патриот	\N	Показ первого сезона сериала проходил с 10 марта по 2 апреля 2020 года на онлайн-сервисе PREMIER и в эфире телеканала «ТНТ»[3][4].\n	{Фэнтези}
75	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гнезда Химер	\N	Был опубликован в издательстве Азбука в 1998 году тиражом 20000 экземпляров  и переиздан в 2000 году. Затем неоднократно переиздавался в издательстве Амфора (в 2000, 2003, 2004, 2005, 2007, 2008, 2010 годах) и в издательстве АСТ.\n	{Фэнтези}
51	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Опочтарение (ЛП)	\N	«Держи марку!» (англ. Going Postal[C 1]) — фэнтези-роман английского писателя Терри Пратчетта, изданный в 2004 году. На русском языке была издана 20 марта 2016 года в переводе Е. Шульги[1][2], ранее в Рунете были опубликованы любительские переводы под наименованием «Опочтарение» и «Послать вразнос».\n	{Фэнтези}
52	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	На всех парах (ЛП)	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Фэнтези}
53	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Делай Деньги (ЛП)	\N	Тридцать шестая книга цикла «Плоский мир», вторая книга из цикла о Мойсте фон Липвиге.\n	{Фэнтези}
77	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Власть несбывшегося	\N	Власть несбывшегося — 5-й (6-й в первом издании) том фэнтези-сериала Лабиринты Ехо авторства Макса Фрая.\n	{Фэнтези}
55	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Землекопы	\N	«Землекопы» и «Крылья» являются продолжением «Угонщиков». При этом события каждого сиквела развиваются параллельно, следуя за определёнными героями. Так, в «Угонщиках» и «Крыльях» центральным персонажем считается Масклин, а в «Землекопах» — Гримма.\n	{Фэнтези}
79	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Темная сторона	\N	«Тёмная полови́на» (англ. The Dark Half, 1989) — роман американского писателя Стивена Кинга.\n	{Фэнтези}
423	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Молния (Покровитель)	\N	\N	{"Ужасы и мистика"}
85	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Отдай моё сердце	\N	Гражданка Украины с видом на жительство в Литве[9]. Училась на филологическом факультете Одесского государственного университета, но университет не окончила. С 1993 года жила в Москве, с 2004 года — в Вильнюсе[10]. В 2000—2001 годах возглавляла сайт NEWSru.com.\n	{Фэнтези}
56	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Угонщики	\N	«Землекопы» и «Крылья» являются продолжением «Угонщиков». При этом события каждого сиквела развиваются параллельно, следуя за определёнными героями. Так, в «Угонщиках» и «Крыльях» центральным персонажем считается Масклин, а в «Землекопах» — Гримма.\n	{Фэнтези}
86	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Я иду искать	\N	Предварительный показ фильма состоялся 27 июля 2019 года на международном кинофестивале «Фантазия»[2]. Кинотеатральная премьера в США состоялась 21 августа 2019 года, в России — 29 августа. Критики оценили фильм положительно, в частности отметив тон, юмор и острые ощущения.\n	{Фэнтези}
91	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ворона на мосту	\N	Ворона на мосту — книга Макса Фрая, 4-я книга серии «Хроники Ехо».\n	{Фэнтези}
59	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Только ты можешь спасти человечество	\N	\N	{Фэнтези}
93	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Горе господина Гро	\N	\N	{Фэнтези}
95	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Обжора-хохотун	\N	\N	{Фэнтези}
62	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сказки старого Вильнюса	\N	\N	{Фэнтези}
63	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сказки старого Вильнюса	\N	\N	{Фэнтези}
64	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сказки старого Вильнюса	\N	\N	{Фэнтези}
65	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сказки старого Вильнюса	\N	\N	{Фэнтези}
66	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сказки старого Вильнюса	\N	\N	{Фэнтези}
67	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сказки старого вильнюса	\N	\N	{Фэнтези}
68	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сказки старого Вильнюса	\N	\N	{Фэнтези}
96	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Властелин Морморы	\N	\N	{Фэнтези}
97	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Неуловимый Хабба Хэн	\N	\N	{Фэнтези}
102	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Волшебник Земноморья	\N	«Волше́бник Земномо́рья» (англ. A Wizard of Earthsea) — первый роман писательницы Урсулы Ле Гуин из цикла о фантастическом архипелаге Земноморье. Книга издана в 1968 году. В том же году роман был награждён премией Boston Globe — Hornbook Award (в категории «juvenile fiction»). История продолжена в книге «Гробницы Атуана».\n	{Фэнтези}
103	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пир стервятников	\N	«Пир стервятников» не только вошел в список бестселлеров Нью-Йорк Таймс, как предыдущие книги серии, но и возглавил его[4]. В 2006 году роман был номинирован на премии «Локус», «Хьюго» и «Британскую премию фэнтези» (BFS): как лучший фантастический роман[5].\n	{Фэнтези}
104	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Буря мечей	\N	Роман был экранизирован в рамках третьего[3] и четвёртого[4] (из-за большого объёма книги) сезона телесериала «Игра престолов».[5] Некоторые завершающие главы таких персонажей, как Дейенерис Таргариен[6][7][8] Джон Сноу[6][7] и Сэмвелл Тарли[6][7][9], были использованы в пятом сезоне телесериала «Игра престолов».[10]\n	{Фэнтези}
105	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Танец с драконами. Грезы и пыль	\N	Первоначально, когда цикл задумался автором как трилогия, название «Танец с драконами» относилось к планируемой второй книге цикла, после «Игры престолов». «Танец с драконами» и предыдущая книга, «Пир стервятников» (2005), изначально писались как один том; возросший объём книги побудил Мартина отделить часть персонажей и сюжетных линий в новую, пятую книгу. На протяжении её большей части повествование идёт параллельно событиям предыдущей книги, но ближе к концу продолжаются и некоторые сюжетные линии из «Пира».\n	{Фэнтези}
106	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Битва королей	\N	«Битва королей» (англ. A Clash of Kings) — роман в жанре эпического фэнтези авторства американского писателя Джорджа Р. Р. Мартина, вторая часть саги «Песнь льда и пламени». Впервые роман был опубликован в США 16 ноября 1998 года.\n	{Фэнтези}
76	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мой Рагнарёк	\N	Макс Фрай — литературный псевдоним сначала двух писателей, Светланы Мартынчик и Игоря Стёпина, впоследствии Светлана Мартынчик писала самостоятельно[1]. 	{Фэнтези}
429	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 06 Апокалипсис Томаса	\N	\N	{"Ужасы и мистика"}
107	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Игра престолов	\N	«Игра престолов» (англ. A Game of Thrones) — роман в жанре фэнтези американского писателя Джорджа Р. Р. Мартина, первая книга из серии «Песнь льда и огня». Впервые произведение было опубликовано в 1996 году издательством Bantam Spectra. Действие романа происходит в вымышленной вселенной. В центре произведения три основные сюжетные линии — события, предшествующие началу династических войн за власть над континентом Вестерос, напоминающим Европу времён Высокого Средневековья; надвигающаяся угроза наступления племён одичалых и демонической расы Иных; а также путешествие дочери свергнутого короля в попытках вернуть Железный трон. Повествование ведётся от третьего лица, попеременно с точки зрения разных персонажей.\n	{Фэнтези}
80	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Книга Одиночеств	\N	\N	{Фэнтези}
81	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Жалобная книга	\N	«Жалобная книга» — рассказ русского писателя Антона Павловича Чехова. Впервые опубликован в журнале «Осколки» № 10 от 10 марта 1884 года под подписью «А. Чехонте».\n	{Фэнтези}
82	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вся правда о нас	\N	Макс Фрай — литературный псевдоним сначала двух писателей, Светланы Мартынчик и Игоря Стёпина, впоследствии Светлана Мартынчик писала самостоятельно[1]. 	{Фэнтези}
83	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сундук Мертвеца	\N	\N	{Фэнтези}
84	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Так берегись	\N	Макс Фрай — литературный псевдоним сначала двух писателей, Светланы Мартынчик и Игоря Стёпина, впоследствии Светлана Мартынчик писала самостоятельно[1]. 	{Фэнтези}
137	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Девочка в стекле	\N	\N	{Фэнтези}
424	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Слуги сумерек (Сумерки)	\N	\N	{"Ужасы и мистика"}
87	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мастер ветров и закатов	\N	Макс Фрай — литературный псевдоним сначала двух писателей, Светланы Мартынчик и Игоря Стёпина, впоследствии Светлана Мартынчик писала самостоятельно[1]. 	{Фэнтези}
88	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мертвый ноль	\N	Братство розенкрейцеров проводит службы духовного исцеления и предлагает заочные курсы по эзотерическому христианству, философии, «духовной астрологии» и библейской интерпретации[4]. Штаб-квартира расположена на горе Экклесия в Оушенсайде, штат Калифорния, а ученики находятся во всём мире, организованные в центрах и учебных группах.[5] Задача братства — обнародовать научный метод развития, особо предназначенный для западных людей, с помощью которого можно сформировать «Душевное тело» (Soul body), чтобы человечество могло приблизить Второе Пришествие[6].[7]\n	{Фэнтези}
89	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Слишком много кошмаров	\N	Макс Фрай — литературный псевдоним сначала двух писателей, Светланы Мартынчик и Игоря Стёпина, впоследствии Светлана Мартынчик писала самостоятельно[1]. 	{Фэнтези}
90	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Джингл-Ко	\N	\N	{Фэнтези}
108	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Танец с драконами. Искры над пеплом	\N	Первоначально, когда цикл задумался автором как трилогия, название «Танец с драконами» относилось к планируемой второй книге цикла, после «Игры престолов». «Танец с драконами» и предыдущая книга, «Пир стервятников» (2005), изначально писались как один том; возросший объём книги побудил Мартина отделить часть персонажей и сюжетных линий в новую, пятую книгу. На протяжении её большей части повествование идёт параллельно событиям предыдущей книги, но ближе к концу продолжаются и некоторые сюжетные линии из «Пира».\n	{Фэнтези}
92	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Хроники Ехо	\N	Макс Фрай — литературный псевдоним сначала двух писателей, Светланы Мартынчик и Игоря Стёпина, впоследствии Светлана Мартынчик писала самостоятельно[1]. 	{Фэнтези}
291	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Магия отступника	\N	После публикациив США «Магия отступника» сразу попала в список бестселлеров The New York Times.[2]\n	{Фэнтези}
94	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дар Шаванахолы	\N	\N	{Фэнтези}
98	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Тубурская игра	\N	Макс Фрай — литературный псевдоним сначала двух писателей, Светланы Мартынчик и Игоря Стёпина, впоследствии Светлана Мартынчик писала самостоятельно[1]. 	{Фэнтези}
430	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 03 Брат Томас	\N	\N	{"Ужасы и мистика"}
99	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	На последнем берегу	\N	«На последнем берегу» (англ. The Farthest Shore) — третья книга фантастического цикла романов американской писательницы Урсулы Ле Гуин об архипелаге Земноморья. Книга издана в 1972 году и является продолжением романа «Гробницы Атуана».\n	{Фэнтези}
100	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Техану	\N	По мотивам романа было создано аниме «Сказания Земноморья», заимствовавшее из оригинального произведения некоторых персонажей, но далеко отошедшее от первоисточника в сюжетом плане.\n	{Фэнтези}
101	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гробница Атуана	\N	Роман получил премию Ньюбери (англ. Newbery Silver Medal) в 1972 году[1].\n	{Фэнтези}
112	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Встретиться вновь	\N	Марк Леви́ (фр. Marc Levy; род. 16 октября 1961 года) — французский писатель-романист, автор романа «Только если это было правдой», по мотивам которого в 2005 году был снят фильм «Между небом и землёй».\n	{Фэнтези}
118	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Те слова, что мы не сказали друг другу	\N	Марк Леви́ (фр. Marc Levy; род. 16 октября 1961 года) — французский писатель-романист, автор романа «Только если это было правдой», по мотивам которого в 2005 году был снят фильм «Между небом и землёй».\n	{Фэнтези}
119	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Конец	\N	\N	{Фэнтези}
120	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Липовый лифт	\N	\N	{Фэнтези}
121	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Скользский склон	\N	\N	{Фэнтези}
122	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Змеиный зал	\N	\N	{Фэнтези}
135	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Физиогномика	\N	Представители экспериментальной психологии относят физиогномику к числу псевдонаук, ставя её в один ряд с месмеризмом, френологией и спиритуализмом[3].\n	{Фэнтези}
136	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вихрь сновидений	\N	\N	{Фэнтези}
123	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Зловещая лесопилка	\N	\N	{Фэнтези}
124	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Огромное окно	\N	\N	{Фэнтези}
126	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Изуверский интернат	\N	\N	{Фэнтези}
127	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гадкий городишко	\N	\N	{Фэнтези}
128	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Предпоследняя передряга	\N	\N	{Фэнтези}
129	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Скверное начало	\N	\N	{Фэнтези}
130	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Угрюмый грот	\N	\N	{Фэнтези}
131	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кровожадный карнавал	\N	\N	{Фэнтези}
132	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Портрет миссис Шарбук	\N	Джеффри Форд (англ. Jeffrey Ford) — американский писатель, пишущий в жанрах фантастики, НФ, фэнтези, мистика.\n	{Фэнтези}
138	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Год призраков	\N	\N	{Фэнтези}
140	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Империя мороженого	\N	Джеффри Форд (англ. Jeffrey Ford) — американский писатель, пишущий в жанрах фантастики, НФ, фэнтези, мистика.\n	{Фэнтези}
143	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Волкодав	\N	«Волкода́в» — серия романов российской писательницы Марии Семёновой. В серию входит 6 книг. Первая была издана в 1995 году, последняя — в 2014.\n	{Фэнтези}
144	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Знамение пути	\N	\N	{Фэнтези}
145	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Самоцветные горы	\N	\N	{Фэнтези}
146	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Истовик-камень	\N	«Волкода́в» — серия романов российской писательницы Марии Семёновой. В серию входит 6 книг. Первая была издана в 1995 году, последняя — в 2014.\n	{Фэнтези}
292	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Лесной маг	\N	\N	{Фэнтези}
147	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Меч мертвых	\N	Мари́я Васи́льевна Семёнова (род. 1 ноября 1958, Ленинград) — русская писательница, литературный переводчик. Наиболее известна как автор серии книг «Волкодав»[2]. Автор многих исторических произведений, в частности исторической энциклопедии «Мы — славяне!»[3]. Одна из основателей поджанра фантастической литературы «славянского фэнтези»[4]. Также автор детективных романов.\n	{Фэнтези}
148	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Там, где лес не растет	\N	Мари́я Васи́льевна Семёнова (род. 1 ноября 1958, Ленинград) — русская писательница, литературный переводчик. Наиболее известна как автор серии книг «Волкодав»[2]. Автор многих исторических произведений, в частности исторической энциклопедии «Мы — славяне!»[3]. Одна из основателей поджанра фантастической литературы «славянского фэнтези»[4]. Также автор детективных романов.\n	{Фэнтези}
149	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Валькирия	\N	\N	{Фэнтези}
150	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Лебединая дорога	\N	Мари́я Васи́льевна Семёнова (род. 1 ноября 1958, Ленинград) — русская писательница, литературный переводчик. Наиболее известна как автор серии книг «Волкодав»[2]. Автор многих исторических произведений, в частности исторической энциклопедии «Мы — славяне!»[3]. Одна из основателей поджанра фантастической литературы «славянского фэнтези»[4]. Также автор детективных романов.\n	{Фэнтези}
109	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Межевой рыцарь	\N	\N	{Фэнтези}
110	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Таинственный рыцарь	\N	\N	{Фэнтези}
111	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Верный меч	\N	\N	{Фэнтези}
151	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Бусый волк	\N	«Волкода́в» — серия романов российской писательницы Марии Семёновой. В серию входит 6 книг. Первая была издана в 1995 году, последняя — в 2014.\n	{Фэнтези}
113	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Семь дней творения	\N	\N	{Фэнтези}
114	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Между небом и землей	\N	\N	{Фэнтези}
115	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Следующий раз	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Фэнтези}
152	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сумерки	\N	Сумерки — первая книга серии «Сумерки» писательницы Стефани Майер, в которой рассказывается о любви обычной семнадцатилетней девушки Изабеллы Свон и вампира Эдварда Каллена. Книга вышла в 2005 году. Вампирский роман, первое издание которого только в США разошлось рекордным тиражом 100 000[1] экземпляров и вошла в список бестселлеров New York Times[2].\n	{Фэнтези}
117	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Где ты	\N	Кни́га — один из видов печатной продукции: непериодическое издание, состоящее из сброшюрованных или отдельных бумажных листов (страниц) или тетрадей, на которых нанесена типографским или рукописным способом текстовая и графическая (иллюстрации) информация, имеющее, как правило, твёрдый переплёт[1].\n	{Фэнтези}
153	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ломая рассвет	\N	«Рассвет» (англ. Breaking Dawn) — четвертый роман серии «Сумерки» писательницы Стефани Майер. Книга вышла впервые в США 2 августа 2008 года, продажа началась в полночь и сопровождалась вечеринками для фанатов на территории книжных магазинов.[1] Первый тираж составлял 3,7 миллионов экземпляров, из которых 1,3 миллиона были раскуплены за первые 24 часа продаж, что стало новым рекордом печатного издательства Hachette Book Group[2]. Книга является продолжением истории о любви обычной девушки Беллы Свон и вампира Эдварда Каллена. Повествование в ней ведётся не только от лица Беллы, но и от имени оборотня Джейкоба.\n	{Фэнтези}
154	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Затмение	\N	«Затмение» — третий роман серии «Сумерки» писательницы Стефани Майер. Книга была опубликована в твердом переплёте в 2007 году. Тираж первого выпуска составил 1 млн экземпляров[1], а за первые сутки после выхода книги было продано более 150 тыс. копий[2]. Экранизация романа вышла 30 июня 2010 года[3]. Она стала третьим фильмом серии.\n	{Фэнтези}
165	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Наложницы Ненависти	\N	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n	{Фэнтези}
166	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ребус Галла	\N	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n	{Фэнтези}
125	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кошмарная клиника	\N	\N	{Фэнтези}
133	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Запределье	\N	\N	{Фэнтези}
134	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Меморанда	\N	Кни́га — один из видов печатной продукции: непериодическое издание, состоящее из сброшюрованных или отдельных бумажных листов (страниц) или тетрадей, на которых нанесена типографским или рукописным способом текстовая и графическая (иллюстрации) информация, имеющее, как правило, твёрдый переплёт[1].\n	{Фэнтези}
157	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гарри Поттер и Тайная комната	\N	«Га́рри По́ттер и Та́йная ко́мната» (англ. Harry Potter and the Chamber of Secrets) — второй роман в серии книг про юного волшебника Гарри Поттера, написанный Джоан Роулинг. Книга рассказывает о втором учебном годе в школе чародейства и волшебства Хогвартс, на котором Гарри и его друзья — Рон Уизли и Гермиона Грейнджер — расследуют таинственные нападения на учеников школы, совершаемые неким «Наследником Слизерина». Объектами нападений являются ученики, среди родственников которых есть неволшебники. Все пострадавшие находятся в оцепенении и ни на что не реагируют. Главному герою предстоит доказать свою непричастность к загадочным событиям и вступить в битву с могущественной темной силой.\n	{Фэнтези}
139	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ночь в тропиках	\N	Тро́пики (от др.-греч. τροπικός κύκλος — поворотный круг) — климатические зоны Земли[источник не указан 74 дня]. Так как угол 23°26′14″ — это угол наклона оси вращения Земли, то в строго географическом понимании тропики расположены между тропиком Козерога (Южным тропиком) и тропиком Рака (Северным тропиком) — основными параллелями, расположенными на 23°26′14″ (или 23,43722°) к югу и северу от экватора и определяющими наибольшую широту, на которой Солнце в полдень может подняться в зенит. На тропике Рака и тропике Козерога Солнце находится в зените только раз в год: в день летнего солнцестояния и в день зимнего солнцестояния соответственно. На всех промежуточных широтах Солнце в полдень оказывается в зените 2 раза в год, один раз при ежегодном перемещении на север и второй раз — на юг.\n	{Фэнтези}
168	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Командор войны	\N	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n	{Фэнтези}
141	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Заклинание мантикоры	\N	\N	{Фэнтези}
142	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Право на поединок	\N	\N	{Фэнтези}
169	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Атака по правилам	\N	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n	{Фэнтези}
158	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гарри Поттер и Филосовский камень	\N	«Га́рри По́ттер и филосо́фский ка́мень» (англ. Harry Potter and the Philosopher's Stone), в США была издана под названием «Гарри Поттер и колдовской камень» (англ. Harry Potter and the Sorcerer's Stone) — первый роман в серии книг про юного волшебника Гарри Поттера, написанный Дж. К. Роулинг. В нём рассказывается, как Гарри узнает, что он волшебник, встречает близких друзей и немало врагов в Школе Чародейства и Волшебства «Хогвартс», а также с помощью своих друзей пресекает попытку возвращения злого волшебника Лорда Волан-де-Морта, который убил родителей Гарри (самому Гарри в тот момент был год от роду).\n	{Фэнтези}
160	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гарри Поттер и узник Азкабана	\N	Гарри Поттер и узник Азкабана (англ. Harry Potter and the Prisoner of Azkaban) — третья книга Джоан Роулинг из серии романов о Гарри Поттере. В третьей книге Гарри Поттер, учащийся на 3-м курсе школы чародейства и волшебства Хогвартс, вместе со своими друзьями Роном Уизли и Гермионой Грейнджер узнает историю Сириуса Блэка — бежавшего из тюрьмы Азкабан волшебника, который подозревается в работе на лорда Волан-де-Морта и о его роли в своей жизни.\n	{Фэнтези}
161	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гарри Поттер и Кубок Огня	\N	Гарри Поттер и Кубок огня (англ. Harry Potter and the Goblet of Fire) — четвёртая книга о приключениях Гарри Поттера, написанная английской писательницей Джоан Роулинг. В Англии опубликована в 2000 году. По сюжету Гарри Поттер против своей воли вовлекается в участие в Турнире Трёх Волшебников, и ему предстоит не только сразиться с более опытными участниками, но и разгадать загадку того, как он вообще попал на турнир вопреки правилам.\n	{Фэнтези}
162	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гарри Поттер и Дары смерти	\N	«Гарри Поттер и Дары Смерти» (англ. Harry Potter and the Deathly Hallows) — седьмая и заключительная книга в серии романов Дж. К. Роулинг о Гарри Поттере.\n	{Фэнтези}
163	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гарри Поттер и Орден Феникса	\N	Гарри Поттер и Орден Феникса (англ. Harry Potter and the Order of the Phoenix) — пятая книга английской писательницы Дж. К. Роулинг о Гарри Поттере. Мировая премьера книги состоялась в Англии летом 2003 года, а российская премьера — в начале 2004. В первые 24 часа с момента начала продаж было продано пять миллионов копий[1]. Является самой длинной книгой в серии.\n	{Фэнтези}
195	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Черная камея	\N	\N	{Фэнтези}
167	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Запах страха	\N	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n	{Фэнтези}
170	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Паутина противостояния	\N	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n	{Фэнтези}
155	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Новолуние	\N	\N	{Фэнтези}
156	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Солнце полуночи	\N	Солнце полуночи — в своё время ожидаемый сопутствующий роман к книге «Сумерки» автора Стефани Майер. Это должно было стать пересказыванием событий, описанных в романе «Сумерки», но повествование бы велось не от лица Беллы Свон, как в первой книге, а от лица Эдварда Каллена.[1] Стефани Майер также заявила, что «Сумерки» — единственная возможная книга из серии, которую она планирует переписать от лица Эдварда.[2] Чтобы лучше передать характер Эдварда, Майер позволила Кэтрин Хардвик, режиссёру адаптации фильма «Сумерки», и Роберту Паттинсону, актёру, играющему Эдварда, прочитать некоторые законченные главы романа, в то время как они снимали кино.[3]\n	{Фэнтези}
171	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Тень Инквизитора	\N	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n	{Фэнтези}
172	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	День Дракона	\N	Крессида Коуэлл (англ. Cressida Cowell; урождённая Хэар; 15 апреля 1966 года, Лондон, Великобритания) — британская писательница, автор книг для детей. Известность ей принесла экранизация её книги — анимационный фильм «Как приручить дракона». Коуэлл сама создаёт иллюстрации к своим книгам.\n	{Фэнтези}
173	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Царь горы	\N	«Царь горы» (англ. King of the Hill) — американский комедийный мультсериал, созданный Майклом Джаджем и Грегом Дэниелсом. Сериал выпускался с 12 января 1997 по 6 мая 2010 года на канале Fox Network. За время своего существования сериал удостоился ряда наград, в том числе двух премий «Эмми»[2].\n	{Фэнтези}
425	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Оборотень среди нас	\N	\N	{"Ужасы и мистика"}
426	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 1 Тихий уголок	\N	\N	{"Ужасы и мистика"}
174	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	И в аду есть герои	\N	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n	{Фэнтези}
175	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Куколка Последней Надежды 	\N	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n	{Фэнтези}
176	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Войны начинают неудачники	\N	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n	{Фэнтези}
177	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Все оттенки черного	\N	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n	{Фэнтези}
178	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Королевский крест	\N	«Правила крови» — сборник повестей и рассказов из цикла романов российского писателя Вадима Панова, написанный в жанре мистическое городское русское фэнтези. В книге представлено 19 произведений различных авторов, победителей конкурса.\n	{Фэнтези}
179	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кафедра странников	\N	«Правила крови» — сборник повестей и рассказов из цикла романов российского писателя Вадима Панова, написанный в жанре мистическое городское русское фэнтези. В книге представлено 19 произведений различных авторов, победителей конкурса.\n	{Фэнтези}
159	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гарри Поттер и Принц-полукровка	\N	\N	{Фэнтези}
299	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Механическая принцесса	\N	Кассандра Клэр (англ. Cassandra Clare; настоящее имя — Джудит Румельт  (англ. Judith Rumelt); род. 31 июля 1973, Тегеран, Иран) — американская писательница. Наиболее известна как автор серии книг «Орудия смерти» и её приквела «Адские механизмы».\n	{Фэнтези}
180	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Занимательная механика	\N	Я́ков Иси́дорович Перельма́н (22 ноября [4 декабря] 1882, Белосток, Гродненская губерния, Российская империя — 16 марта 1942, Ленинград, СССР) — русский и советский математик, физик, журналист и педагог. Член Русского общества любителей мироведения, популяризатор точных наук, основоположник жанра занимательной науки, автор понятия «научно-фантастическое»[2]. Брат русско-еврейского прозаика и драматурга Осипа Дымова.\n	{Фэнтези}
182	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Таганский перекресток	\N	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n	{Фэнтези}
184	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Наследница ведьм	\N	Цикл создан в 1990—1994 годах, а в начале XXI века переведён на русский язык.\n	{Фэнтези}
164	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Тепло наших тел	\N	«Тепло наших тел» (англ. Warm Bodies) — роман, написанный американским блогером Айзеком Марионом, по которому в 2013 году вышел одноимённый фильм режиссёра Джонатана Ливайна.\n	{Фэнтези}
185	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Талтос	\N	\N	{Фэнтези}
186	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мейфейрские ведьмы	\N	Цикл создан в 1990—1994 годах, а в начале XXI века переведён на русский язык.\n	{Фэнтези}
187	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Лэшер	\N	«Лэ́шер» (англ. Lasher) — второй роман американской писательницы Энн Райс из цикла «Мэйфейрские ведьмы». Вошёл в список бестселлеров по версии Publishers Weekly за 1993 год.\n	{Фэнтези}
188	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Невеста дьявола	\N	\N	{Фэнтези}
189	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Час ведьмовства	\N	\N	{Фэнтези}
190	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кровь и золото	\N	Энн Райс (англ. Anne Rice, имя при рождении — Говард Аллен О’Брайен (англ. Howard Allen O’Brien); род. 4 октября 1941, Новый Орлеан, Луизиана, США) — американская писательница, сценарист и продюсер. Наибольшую известность писательнице принёс роман «Интервью с вампиром», который обязан своей популярностью одноимённому фильму.\n	{Фэнтези}
191	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вампир Лестат	\N	«Вампи́р Леста́т» (англ. The Vampire Lestat) — роман американской писательницы Энн Райс, второй том цикла «Вампирские хроники», следующий за романом «Интервью с вампиром». Многие события двух книг противоречат друг другу. Такое повествование позволяет читателю самому решать кому из ненадёжных рассказчиков верить — Луи или Лестату.\n	{Фэнтези}
192	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Интервью с вампиром	\N	«Интервью́ с вампи́ром» (англ. Interview with the Vampire) — роман американской писательницы Энн Райс, первый том цикла «Вампирские хроники». Роман описывает историю жизни вампира Луи, рассказываемую им молодому репортёру Дэниелу Моллою. Райс написала этот роман в 1973 году, а впервые он был напечатан в 1976. На сегодняшний день произведение имеет тираж около 8 миллионов копий[1].\n	{Фэнтези}
193	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вампир Арман	\N	\N	{Фэнтези}
194	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	История похитителя тел	\N	Действие романа разворачивается полностью в XX веке, что отличает его от других книг Райс, в которых она часто погружает читателей в прошлое.\n	{Фэнтези}
196	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Царица проклятых	\N	«Цари́ца про́клятых» (англ. The Queen of the Damned) — роман американской писательницы Энн Райс, третий том цикла «Вампирские хроники», следующий за романами «Интервью с вампиром» и «Вампир Лестат». Он продолжает историю, которая описана в романе «Вампир Лестат» до автобиографии Лестата. В «Царице проклятых» рассказано о происхождении и истории вампиров, зародившейся в Древнем Египте после того, как в вампира была обращена его королева Акаша.\n	{Фэнтези}
198	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Меррик	\N	«Ме́ррик» или «Мерри́к»[1] (англ. Merrick) — седьмой роман из серии «Вампирские хроники» американской писательницы Энн Райс, опубликованный в 2000 году.\n	{Фэнтези}
205	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Змейка	\N	Это четвертое старейшее тайное общество университета (первое — «Череп и кости», второе — «Свиток и ключ», третье — «Волчья голова»).\n	{Фэнтези}
207	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Крадущийся в тени	\N	\N	{Фэнтези}
208	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Джанга с тенями	\N	\N	{Фэнтези}
211	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Колдун из клана смерти	\N	Кассандра Клэр (англ. Cassandra Clare; настоящее имя — Джудит Румельт  (англ. Judith Rumelt); род. 31 июля 1973, Тегеран, Иран) — американская писательница. Наиболее известна как автор серии книг «Орудия смерти» и её приквела «Адские механизмы».\n	{Фэнтези}
212	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Основатель	\N	\N	{Фэнтези}
219	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пятая гора	\N	\N	{Фэнтези}
220	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Алхимик	\N	«Алхи́мик» (порт. O Alquimista) — роман Пауло Коэльо, изданный в 1988 году и ставший мировым бестселлером[1]. Издан более чем в 117 странах мира, переведён на 81 язык.\n	{Фэнтези}
222	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Победитель остается один	\N	\N	{Фэнтези}
226	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дьявол и сеньорита Прим	\N	Книга пытается найти ответ на вопрос: «Есть ли плохие люди».\n	{Фэнтези}
227	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вероника решает умереть	\N	Книга входит в серию «И в день седьмой…» вместе с другими двумя произведениями автора («На берегу Рио-Пьедра села я и заплакала», «Дьявол и сеньорита Прим»).[1]\n	{Фэнтези}
228	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ледяной укус	\N	«Академия вампиров» (англ. Vampire Academy) — серия романтических книг о вампирах, созданная американской писательницей Райчел Мид. Первый роман был опубликован в 2007 году. В них описываются приключения семнадцатилетней девушки-дампира Розмари Хэзевей, которая обучается на специальность телохранителя для своей подруги, принцессы Лиссы, в вампирской школе — Академии св. Владимира.\n	{Фэнтези}
230	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Последняя жертва	\N	\N	{Фэнтези}
286	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Золотой Шут	\N	«Король и Шут» (сокращённо «КиШ») — российская хоррор-панк-группа из Санкт-Петербурга.\n	{Фэнтези}
231	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Поцелуй тьмы	\N	«Академия вампиров» (англ. Vampire Academy) — серия романтических книг о вампирах, созданная американской писательницей Райчел Мид. Первый роман был опубликован в 2007 году. В них описываются приключения семнадцатилетней девушки-дампира Розмари Хэзевей, которая обучается на специальность телохранителя для своей подруги, принцессы Лиссы, в вампирской школе — Академии св. Владимира.\n	{Фэнтези}
232	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Оковы для призрака	\N	«Академия вампиров» (англ. Vampire Academy) — серия романтических книг о вампирах, созданная американской писательницей Райчел Мид. Первый роман был опубликован в 2007 году. В них описываются приключения семнадцатилетней девушки-дампира Розмари Хэзевей, которая обучается на специальность телохранителя для своей подруги, принцессы Лиссы, в вампирской школе — Академии св. Владимира.\n	{Фэнтези}
234	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Возвращение домой	\N	Розамунда Пилчер, урождённая Скотт (англ. Rosamunde Pilcher, 22 сентября 1924, Лелант, Корнуолл, Англия — 6 февраля 2019, Лонгфорган[en], Шотландия) — английская писательница, мастер «женского романа».\n	{Фэнтези}
235	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кольцо нибелунгов	\N	«Кольцо́ нибелу́нга» (нем. Der Ring des Nibelungen; Nibelung — «дитя тумана») — название цикла из четырёх эпических опер, основанных на реконструкциях германской мифологии, исландских сагах и средневековой поэме «Песнь о Нибелунгах»:\n	{Фэнтези}
238	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дракула	\N	«Дра́кула» (англ. Dracula) — роман ирландского писателя Брэма Стокера, впервые опубликованный в 1897 году[1]. Главный антагонист — вампир-аристократ граф Дракула.\n	{Фэнтези}
181	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ручной Привод	\N	Iomega Zip — семейство накопителей на гибких магнитных дисках, аналоги дискет, имеющие бо́льшую ёмкость. Разработаны компанией Iomega[1] в конце 1994. Изначально имели ёмкость около 100 мегабайт, в поздних версиях она была увеличена до 250 и 750 мегабайт.\n	{Фэнтези}
247	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Властелин Хаоса	\N	Роберт Джордан (англ. Robert Jordan; 17 октября 1948 — 16 сентября 2007) — псевдоним американского писателя; настоящее имя — Джеймс Оливер Ригни-младший (англ. James Oliver Rigney, Jr.). Получил широкую известность как автор цикла «Колесо Времени». Писал также под именами Реган О’Нил (англ. Regan O’Neal) и Джексон О’Рейли (англ. Jackson O’Reilly).\n	{Фэнтези}
183	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Рин	\N	\N	{Фэнтези}
248	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Нож Сновидений	\N	Роберт Джордан (англ. Robert Jordan; 17 октября 1948 — 16 сентября 2007) — псевдоним американского писателя; настоящее имя — Джеймс Оливер Ригни-младший (англ. James Oliver Rigney, Jr.). Получил широкую известность как автор цикла «Колесо Времени». Писал также под именами Реган О’Нил (англ. Regan O’Neal) и Джексон О’Рейли (англ. Jackson O’Reilly).\n	{Фэнтези}
250	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сердце Зимы	\N	Роберт Джордан (англ. Robert Jordan; 17 октября 1948 — 16 сентября 2007) — псевдоним американского писателя; настоящее имя — Джеймс Оливер Ригни-младший (англ. James Oliver Rigney, Jr.). Получил широкую известность как автор цикла «Колесо Времени». Писал также под именами Реган О’Нил (англ. Regan O’Neal) и Джексон О’Рейли (англ. Jackson O’Reilly).\n	{Фэнтези}
251	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Перекрестки Сумерек	\N	Роберт Джордан (англ. Robert Jordan; 17 октября 1948 — 16 сентября 2007) — псевдоним американского писателя; настоящее имя — Джеймс Оливер Ригни-младший (англ. James Oliver Rigney, Jr.). Получил широкую известность как автор цикла «Колесо Времени». Писал также под именами Реган О’Нил (англ. Regan O’Neal) и Джексон О’Рейли (англ. Jackson O’Reilly).\n	{Фэнтези}
252	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Корона мечей	\N	Роберт Джордан (англ. Robert Jordan; 17 октября 1948 — 16 сентября 2007) — псевдоним американского писателя; настоящее имя — Джеймс Оливер Ригни-младший (англ. James Oliver Rigney, Jr.). Получил широкую известность как автор цикла «Колесо Времени». Писал также под именами Реган О’Нил (англ. Regan O’Neal) и Джексон О’Рейли (англ. Jackson O’Reilly).\n	{Фэнтези}
253	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Грядущая Буря	\N	Роберт Джордан (англ. Robert Jordan; 17 октября 1948 — 16 сентября 2007) — псевдоним американского писателя; настоящее имя — Джеймс Оливер Ригни-младший (англ. James Oliver Rigney, Jr.). Получил широкую известность как автор цикла «Колесо Времени». Писал также под именами Реган О’Нил (англ. Regan O’Neal) и Джексон О’Рейли (англ. Jackson O’Reilly).\n	{Фэнтези}
259	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Последнее желание	\N	«Последнее желание» (польск. Ostatnie życzenie) — сборник рассказов писателя Анджея Сапковского в жанре фэнтези, объединённых общим персонажем — ведьмаком Геральтом из Ривии. Это первое произведение из цикла «Ведьмак» как по хронологии, так и по времени написания. От первого издания в виде книги «Ведьмак» «Последнее желание» отличается связующей серией интерлюдий «Глас рассудка» и наличием рассказов «Последнее желание» и «Край света».\n	{Фэнтези}
263	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Хрустальный грот	\N	\N	{Фэнтези}
265	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Принц и паломница	\N	«Ма́ленький принц» (фр. Le Petit Prince) — аллегорическая повесть-сказка, наиболее известное произведение Антуана де Сент-Экзюпери.\n	{Фэнтези}
267	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Рождение огня	\N	Джордж Ре́ймонд Ри́чард Ма́ртин (англ. George Raymond Richard Martin, род. 20 сентября 1948) — современный американский писатель-фантаст, сценарист, продюсер и редактор, лауреат многих литературных премий. В 1970—1980-е годы получил известность благодаря рассказам и повестям в жанре научной фантастики, литературы ужасов и фэнтези. Наибольшую славу ему принес выходящий с 1996 года фэнтезийный цикл «Песнь Льда и Огня», позднее экранизированный компанией HBO в виде популярного телесериала «Игра престолов». Эти книги дали основания литературным критикам называть Мартина «американским Толкином»[5]. В 2011 году журнал Time включил Джорджа Мартина в свой список самых влиятельных людей в мире[6].\n	{Фэнтези}
268	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Голодные игры	\N	«Голодные игры» (англ. The Hunger Games) — первый роман в одноимённой трилогии американской писательницы Сьюзен Коллинз. В США роман вышел в 2008 году (в России издан в 2010 году) и за короткое время стал бестселлером. Коллинз продала права на экранизацию компании Lionsgate, одноимённый фильм вышел в прокат 22 марта 2012 года.\n	{Фэнтези}
269	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Перси Джексон и море чудовищ	\N	\N	{Фэнтези}
270	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Перси Джексон и последний олимпиец	\N	Перси Джексон и Последнее Пророчество — последняя книга из серии 5 книг, основанная на Греческой мифологии, о приключениях подростка полубога Перси Джексона, сына Посейдона.\n	{Фэнтези}
199	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Аллигент	\N	Allegiant is a science fiction novel for young adults,[1] written by the American author Veronica Roth and published by HarperCollins in October 2013. It completes the Divergent trilogy that Roth started with her debut novel Divergent in 2011.[1][3][4][5][6][7] The book is written from the perspective of both Beatrice (Tris) and Tobias (Four).[8] Following the revelations of the previous novel, they journey past the city's boundaries to discover what lies beyond.\n	{Фэнтези}
200	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Инсургент 	\N	Инсургент (англ. insurgent — «мятежник», «повстанец») — вторая книга трилогии американской писательницы Вероники Рот, написанной в жанре постапокалиптической антиутопии. В США вышла 1 мая 2012 года[2]. Первая книга вышла 3 мая 2011 года и называется «Дивергент»[3], третья — «Эллигент» вышла 22 октября 2013 года[4].\n	{Фэнтези}
271	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Перси Джексон и проклятие титана	\N	«Перси Джексон и Проклятие титана» (англ. The Titan's Curse) — это третья книга из серии про Перси Джексона. Эта книга описывает приключения четырнадцатилетнего полубога Перси Джексона,сына Посейдона. На этот раз Перси и его друзьям предстоит отправиться на поиски Артемиды, богини охоты, и Аннабет, дочери Афины, встретиться с Атласом и Лукой, сыном Гермеса.\n	{Фэнтези}
202	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дивергент	\N	\N	{Фэнтези}
203	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Аутодафе	\N	\N	{Фэнтези}
204	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Страж	\N	«Страж» (англ. The Watcher) — мистический роман английского писателя Чарльза Маклина, впервые издан в 1982 году. На русском языке впервые издан в 1999 году в переводе Виктора Топорова.\n	{Фэнтези}
272	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Перси Джексон и похититель молний	\N	Перси Джексон и Похититель молний — роман Рика Риордана в жанре фэнтези. В России был переведён и выпущен в 2009 году.\n	{Фэнтези}
206	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вьюга теней	\N	\N	{Фэнтези}
287	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Судьба Шута	\N	\N	{Фэнтези}
273	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Перси Джексон и олимпийцы. Секретные материалы	\N	«Перси Джексон и Олимпийцы. Секретные материалы» — дополнение к циклу книг о Перси Джексоне, содержащее три рассказа Рика Риордана о приключениях Перси — «Перси Джексон и Украденная колесница», «Перси Джексон и Бронзовый Дракон», «Перси Джексон и Меч Аида», а также ряд интервью с главными героями цикла, кроссворд, цветные вклейки с краткими характеристиками богов-олимпийцев. События «Меча Аида» являются прямым продолжением «Лабиринта Смерти» и навязываются на «Последнее пророчество».\n	{Фэнтези}
209	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Начинается вьюга	\N	Ян Бе́нё (также Бенио или Беньо, род. 3 октября 1933, Слатинка, округ Зволен) — словацкий прозаик, публицист, переводчик, автор книг для молодёжи.\n	{Фэнтези}
210	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кровные братья	\N	\N	{Фэнтези}
274	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Перси Джексон и лабиринт смерти	\N	Перси Джексон и Лабиринт смерти — фэнтези, роман приключений основан на греческой мифологии, это четвертая книга из серии «Перси Джексон и олимпийцы» автора Рика Риордана.  Полубог Перси Джексон пытается остановить Луку и его армию от вторжения в лагерь полукровок, которые пытаются пробраться через лабиринт Дедала. Дословный перевод названия книги — «Битва за лабиринт».\n	{Фэнтези}
213	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Звездная пыль	\N	«Звёздная пыль» (англ. Stardust) — книга британского писателя Нила Геймана в жанре фэнтези. «Звёздная пыль» имеет отличный от других новелл Геймана стиль написания, поскольку следует традициям авторов фэнтези, работавших до Дж. Р. Р. Толкина, таких, как Лорд Дансени и Джеймс Брэнч Кэйбелл.\n	{Фэнтези}
300	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Механический принц	\N	\N	{Фэнтези}
301	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Трилогия о Драко	\N	\N	{Фэнтези}
214	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Коралина	\N	«Коралина»  (англ. Coraline) — детская повесть, написанная в 2002 году английским писателем-фантастом Нилом Гейманом. На русском языке повесть впервые была опубликована в 2005 году. Книга получила ряд престижных премий: премию Небьюла за лучшую повесть[1], премию Хьюго за лучшую повесть[2], премию Брэма Стокера для молодых читателей[3], премию Локус[4] за лучшую повесть для подростков. В 2009 году по повести был снят мультипликационный фильм, в России вышедший в прокате под названием «Коралина в Стране Кошмаров».\n	{Фэнтези}
215	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Заир	\N	«Заир» — роман 2005 года писателя Пауло Коэльо.\n	{Фэнтези}
216	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мактуб	\N	\N	{Фэнтези}
217	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ведьма с Портобелло	\N	Часть книги Пауло Коэльо публиковал еженедельно на своем блогe, где каждый может поделиться впечатлением о прочитанном.\n	{Фэнтези}
218	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Рождественская сказка	\N	\N	{Фэнтези}
276	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Возвращение Короля	\N	По мотивам романа новозеландский режиссёр Питер Джексон в 2003 году снял фильм «Властелин колец: Возвращение короля».\n	{Фэнтези}
277	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Две Крепости	\N	По мотивам романа новозеландский режиссёр Питер Джексон в 2002 году снял фильм «Властелин колец: Две крепости».\n	{Фэнтези}
221	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дневник мага	\N	\N	{Фэнтези}
278	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Хоббит, или Туда и обратно	\N	«Хо́ббит, или Туда́ и обра́тно» (англ. The Hobbit, or There and Back Again) — повесть английского писателя Джона Р. Р. Толкина. Впервые опубликована в 1937 году издательством George Allen & Unwin, став со временем классикой детской литературы. В основе сюжета — путешествие хоббита Бильбо Бэггинса, волшебника Гэндальфа и тринадцати гномов во главе с Торином Дубощитом. Их путь лежит к Одинокой Горе, где находятся гномьи сокровища, охраняемые драконом Смаугом.\n	{Фэнтези}
223	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Одиннадцать минут	\N	\N	{Фэнтези}
224	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Брида	\N	\N	{Фэнтези}
225	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	На берегу Рио-Пьедра	\N	«…Любящему покоряется мир и неведом страх потери. Истинная любовь — это когда отдаёшь себя всего без остатка… Рано или поздно каждому из нас придётся преодолеть свои страхи — ибо духовная стезя пролегает через повседневный опыт любви».'\n«На берегу Рио-Пьедра села я и заплакала…» — первый роман трилогии «В день седьмой», куда входят также «Вероника решает умереть» и «Дьявол и сеньорита Прим». Это роман о любви, о том, что она — главное в нашей жизни, и через неё можно точно так же прийти к Богу, как и через служение Ему в роли монаха-чудотворца. А ещё о том, что рано или поздно каждому из нас приходится преодолевать свои страхи и делать выбор.\n	{Фэнтези}
279	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Волшебный корабль	\N	\N	{Фэнтези}
346	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Записки усталого романтика	\N	\N	{Юмор}
280	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Корабль судьбы 2	\N	В этом романе завершаются все сюжетные линии «Волшебного корабля» и «Безумного корабля», раскрывается тайна живых кораблей. Имеются отсылки к «Саге о Видящих»[3], так как действие происходит в той же вселенной. Книга была отмечена, в основном, положительными рецензиями.\n	{Фэнтези}
229	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Охотники и жертвы	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Фэнтези}
281	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Корабль судьбы 1	\N	В этом романе завершаются все сюжетные линии «Волшебного корабля» и «Безумного корабля», раскрывается тайна живых кораблей. Имеются отсылки к «Саге о Видящих»[3], так как действие происходит в той же вселенной. Книга была отмечена, в основном, положительными рецензиями.\n	{Фэнтези}
282	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Безумный корабль	\N	Действие происходит после событий первого романа — «Волшебный корабль». В «Безумном корабле» продолжается рассказ о семействе Вестритов и их борьбе за выживание после смерти главы семьи. Алтия по-прежнему пытается вернуть звание капитана корабля «Проказница», а Кеннет продолжает кампанию против работорговцев и вынашивает планы объединения пиратских островов в централизованное государство. Так же большая часть книги описывает действие в городе Удачном, рассказывает о приключениях Малты Вестрит-Хэвен (племянница Алтии) и ее близких. О взаимоотношениях между жителями Дождевых Чащоб и жителями города Удачный. Про сатрапа и его Подруг. В этой книге можно почерпнуть понимание о связи между драконами, и живыми кораблями. И конечно найдется описание знакомства Янтарь с Безумным кораблем «Соврешенным» (это он на обложке книги) и к чему это знакомство привело. а также продолжение приключений Уинтроу (брат Малты). В книге много уделяется описанию чувств и переживаний главных героев. И чем ближе к концу этой истории, тем понятнее, зачем этот прием применяется.\n	{Фэнтези}
233	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кровная клятва	\N	\N	{Фэнтези}
297	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Город Драконов	\N	Елена Звёздная — современная российская писательница, автор книг в жанре «любовного юмористического фэнтези».\n	{Фэнтези}
298	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Механический ангел	\N	Кассандра Клэр (англ. Cassandra Clare; настоящее имя — Джудит Румельт  (англ. Judith Rumelt); род. 31 июля 1973, Тегеран, Иран) — американская писательница. Наиболее известна как автор серии книг «Орудия смерти» и её приквела «Адские механизмы».\n	{Фэнтези}
236	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Месть нибелунгов	\N	\N	{Фэнтези}
237	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Лис.rtf	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Фэнтези}
304	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Город потерянных душ	\N	Кассандра Клэр (англ. Cassandra Clare; настоящее имя — Джудит Румельт  (англ. Judith Rumelt); род. 31 июля 1973, Тегеран, Иран) — американская писательница. Наиболее известна как автор серии книг «Орудия смерти» и её приквела «Адские механизмы».\n	{Фэнтези}
239	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пямять Света	\N	\N	{Фэнтези}
240	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Путь Кинжалов	\N	\N	{Фэнтези}
241	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Огни Небес	\N	\N	{Фэнтези}
242	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Возрожденный Дракон	\N	\N	{Фэнтези}
243	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Око Мира	\N	\N	{Фэнтези}
244	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Великая Охота	\N	\N	{Фэнтези}
245	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Новая Весна	\N	\N	{Фэнтези}
246	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Башни Полуночи	\N	\N	{Фэнтези}
307	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Эрагон	\N	«Эрагон» (англ. Eragon) — роман, написанный Кристофером Паолини и первая книга тетралогии «Наследие».\n	{Фэнтези}
308	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мертв как гвоздь	\N	Шарли́н Ха́ррис (англ. Charlaine Harris) — американская писательница, автор четырёх успешных детективных книжных сериалов[9], в том числе и о Суки Стакхаус (англ. Sookie Stackhouse, возможны варианты перевода Соки или Сьюки), по мотивам которого создан драматический телевизионный сериал «Настоящая кровь».\n	{Фэнтези}
249	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Восходящая Тень	\N	\N	{Фэнтези}
312	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Клуб мертвяков	\N	Шарли́н Ха́ррис (англ. Charlaine Harris) — американская писательница, автор четырёх успешных детективных книжных сериалов[9], в том числе и о Суки Стакхаус (англ. Sookie Stackhouse, возможны варианты перевода Соки или Сьюки), по мотивам которого создан драматический телевизионный сериал «Настоящая кровь».\n	{Фэнтези}
314	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Окончательно мертв	\N	Шарли́н Ха́ррис (англ. Charlaine Harris) — американская писательница, автор четырёх успешных детективных книжных сериалов[9], в том числе и о Суки Стакхаус (англ. Sookie Stackhouse, возможны варианты перевода Соки или Сьюки), по мотивам которого создан драматический телевизионный сериал «Настоящая кровь».\n	{Фэнтези}
302	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Город праха	\N	Город праха (англ. City of Ashes) — вторая книга цикла Орудия смерти американской писательницы Кассандры Клэр.\n	{Фэнтези}
427	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 2 Комната шепотов	\N	\N	{"Ужасы и мистика"}
316	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Собачье сердце	\N	«Собачье сердце» — повесть Михаила Афанасьевича Булгакова.\n	{Фэнтези}
330	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Манюня. Юбилей Ба	\N	Наринэ Юрьевна Абгарян (арм. Նարինե Յուրիի Աբգարյան; род. 14 января 1971, г. Берд, Тавуш, Армения) — армянская русскоязычная писательница[1], блогер. Лауреат премии "Ясная Поляна" (2016) и номинант "Большой книги" (2011). Автор бестселлеров «Манюня» и «Люди, которые всегда со мной»[2]. В 2020 году The Guardian называет её в числе самых ярких авторов Европы[3].\n	{Юмор}
317	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мастер и Маргарита	\N	«Ма́стер и Маргари́та» — роман Михаила Афанасьевича Булгакова, работа над которым началась в конце 1920-х годов и продолжалась вплоть до смерти писателя. Роман относится к незавершённым произведениям; редактирование и сведение воедино черновых записей осуществляла после смерти мужа вдова писателя — Елена Сергеевна. Первая версия романа, имевшая названия «Копыто инженера», «Чёрный маг» и другие, была уничтожена Булгаковым в 1930 году. В последующих редакциях среди героев произведения появились автор романа о Понтии Пилате и его возлюбленная. Окончательное название — «Мастер и Маргарита» — оформилось в 1937 году.\n	{Фэнтези}
319	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мцыри	\N	\N	{Поэзия}
254	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кровь эльфов	\N	Кровь эльфов (польск. Krew elfów) — третья книга из цикла «Ведьмак» польского писателя Анджея Сапковского.\n	{Фэнтези}
255	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Меч предназначения	\N	\N	{Фэнтези}
256	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Крещение огнем	\N	Крещение огнём (польск. Chrzest ognia) — пятая книга из цикла «Ведьмак» польского писателя Анджея Сапковского. Первая публикация в Польше в 1996 году, в России в 1997 году.\n	{Фэнтези}
257	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Час презрения	\N	Time of Contempt (Polish original title: Czas pogardy, early title was translated less literally as Time of Anger) is the second novel in the Witcher Saga written by Polish fantasy writer Andrzej Sapkowski, first published 1995 in Polish, and 2013 in English (under the title The Time of Contempt). It is a sequel to the first Witcher novel Blood of Elves (Krew elfów) and is followed by Baptism of Fire (Chrzest ognia).[1]\n	{Фэнтези}
258	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Башня ласточки	\N	\N	{Фэнтези}
320	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Король Лир	\N	«Коро́ль Лир» (англ. The Tragedy of King Lear) — пьеса Уильяма Шекспира, написанная в 1605—1606 годах. Впервые напечатана в 1608 году. Основой сюжета трагедии было предание о короле Лире и его дочерях.\n	{Поэзия}
260	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Владычица озера	\N	«Владычица Озера» (польск. Pani Jeziora) — седьмая книга из цикла «Ведьмак» польского писателя Анджея Сапковского.\n	{Фэнтези}
261	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Последнее волшебство	\N	\N	{Фэнтези}
322	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гамлет, принц датский	\N	\N	{Поэзия}
323	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сирано де Бержерак	\N	Эркю́ль Савинье́н Сирано́ де Бержера́к (фр. Hercule Savinien Cyrano de Bergerac, 6 марта 1619, Париж — 28 июля 1655, Саннуа) — французский драматург, философ, поэт и писатель, один из предшественников научной фантастики, гвардеец. Прототип героя пьесы Эдмона Ростана «Сирано де Бержерак».\n	{Поэзия}
264	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	День гнева	\N	«День гнева» (исп. Un día de cólera) — роман Артуро Переса-Реверте, вышедший в 2007 году.\n	{Фэнтези}
325	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Новый декамерон	\N	«Декамеро́н» (итал. Il Decamerone от др.-греч. δέκα «десять» + ἡμέρα «день»: букв. «Десятиднев») — собрание ста новелл итальянского писателя Джованни Боккаччо, одна из самых знаменитых книг раннего итальянского Ренессанса, написанная приблизительно в 1352—1354 годы. Большинство новелл этой книги посвящено теме любви, начиная от её эротического и заканчивая трагическим аспектами.\n	{Юмор}
266	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сойка-пересмешница	\N	\N	{Фэнтези}
326	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Я постепенно познаю	\N	\N	{Юмор}
345	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Придумано в СССР	\N	Кни́га — один из видов печатной продукции: непериодическое издание, состоящее из сброшюрованных или отдельных бумажных листов (страниц) или тетрадей, на которых нанесена типографским или рукописным способом текстовая и графическая (иллюстрации) информация, имеющее, как правило, твёрдый переплёт[1].\n	{Юмор}
327	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дневник Домового	\N	Домово́й (кутный бог) — у славянских народов домашний дух, мифологический хозяин и покровитель дома, обеспечивающий нормальную жизнь семьи, плодородие, здоровье людей, животных[1].\n	{Юмор}
331	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Манюня пишет фантастический роман	\N	Наринэ Юрьевна Абгарян (арм. Նարինե Յուրիի Աբգարյան; род. 14 января 1971, г. Берд, Тавуш, Армения) — армянская русскоязычная писательница[1], блогер. Лауреат премии "Ясная Поляна" (2016) и номинант "Большой книги" (2011). Автор бестселлеров «Манюня» и «Люди, которые всегда со мной»[2]. В 2020 году The Guardian называет её в числе самых ярких авторов Европы[3].\n	{Юмор}
332	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Свадебное путешествие Лелика	\N	\N	{Юмор}
335	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Записки кота Шашлыка	\N	\N	{Юмор}
336	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Записки невесты программиста	\N	\N	{Юмор}
341	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пиар во время чумы	\N	Габриэ́ль Хосе́ де ла Конко́рдиа «Гáбо» Гарси́а Ма́ркес[6][7] (исп. Gabriel José de la Concordia «Gabo» García Márquez [ɡaˈβɾjel ɡarˈsia ˈmarkes]; 6 марта 1927[8], Аракатака — 17 апреля 2014, Мехико[9]) — колумбийский писатель-прозаик, журналист, издатель и политический деятель. Лауреат Нейштадтской литературной премии (1972) и Нобелевской премии по литературе (1982). Представитель литературного направления «магический реализм».\n	{Юмор}
342	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Большой концерт	\N	\N	{Юмор}
344	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Умом Россию не поднять	\N	\N	{Юмор}
394	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Код розенкрейцеров	\N	Книга разделена на три части. В первой части автор пишет: о «видимых и невидимых мирах»; об «истинном строении и способе эволюции человека», о периодическом «возрождении человека» и о «законе причины и следствия». Вторая часть посвящена космогенезу и антропогенезу. Здесь речь идёт об «отношении человека к Богу»; о «схеме эволюции» вообще и об «эволюции Солнечной системы и Земли» в частности. В третьей части говорится об «Иисусе Христе и Его миссии»[K 10][K 11]; о «будущем развитии человека и Посвящении»; об «оккультном обучении и безопасном методе получения знания из первых рук».\n	{"Ужасы и мистика"}
347	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сила чисел	\N	Книга Чи́сел (ивр. ‏בְּמִדְבַּר‏‎, bᵊmiðbar, совр. произн. Бе-мидба́р — «В пустыне»; лат. Numeri; др.-греч. Ἀριθμοί; тж. «Четвёртая книга Моисея») — четвёртая книга Пятикнижия (Торы), Ветхого Завета и всей Библии. В Мишне и Талмуде[1] называется «Хумаш а-пкудим» (букв. «Пятина исчисленных»). Название книги объясняется тем, что в ней приводится целый ряд подробных данных по исчислению народа, отдельных его колен, священнослужителей, первенцев и т. п. Повествование охватывает события от приготовлений к уходу из Синая до прибытия «на равнины Моава, при Иордане, против Иерихона». Основное содержание этой книги — жизнь народа в пустыне, пред лицом Создателя и «наедине» с Ним.\n	{Юмор}
364	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дживс и песнь песней	\N	Песнь песней Соломона (др.-евр. שִׁיר הַשִּׁירִים, шир хa-ширим, греч. ᾆσμα ᾀσμάτων, ὃ ἐστι Σαλώμων, лат. Canticum Canticorum Salomonis) — книга, входящая в состав еврейской Библии (Танаха)[1] и Ветхого Завета. Четвёртая книга раздела Ктувим еврейской Библии. Написана на библейском иврите и приписывается царю Соломону. В настоящее время обычно толкуется как сборник свадебных песен без единого сюжета (возможно, воспроизводящий структуру свадебных обрядов)[2], но может интерпретироваться как история любви царя Соломона и девушки Суламиты[3] либо как противопоставление чистой любви Суламиты к пастуху и участи женщин в гареме Соломона[4].\n	{Юмор}
375	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Илиада	\N	\N	{"Старинная литература"}
378	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Легенды и мифы Древней Греции	\N	\N	{Мифы,легенды}
381	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Я-легенда	\N	«Я — легенда» (англ. I Am Legend) — научно-фантастический роман американского писателя Ричарда Мэтисона, оказавший большое влияние на формирование в современной литературе образа вампиров, зомби, популяризации концепции всемирного апокалипсиса по причине пандемии и идеи описания вампиризма как заболевания. Роман, опубликованный в 1954 году, был достаточно успешен. По его мотивам сняты фильмы «Последний человек на Земле» (1964), «Человек Омега» (1971) и «Я — легенда» (2007). Кроме того, существует неофициальная экранизация — фильм «Я — воин» (2007).\n	{"Ужасы и мистика"}
384	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Тьма	\N	«Тьма» (англ. Dark) — немецкий драматический и научно-фантастический веб-сериал, созданный Бараном бо Одаром и Янтье Фризе. Он состоит из трёх сезонов, выходивших с 2017 по 2020 год. Действие сериала разворачивается в вымышленном городке Винден (Германия). События, начало которым положило исчезновение двух детей, раскрывают тайны и скрытые связи четырёх семей Виндена, которые постепенно узнают зловещую тайну о путешествиях во времени, затрагивающих несколько поколений. На протяжении всего сериала исследуются экзистенциальный смысл времени и его влияние на человеческую природу.\n	{"Ужасы и мистика"}
428	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Звездная кровь	\N	\N	{"Ужасы и мистика"}
388	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Солнце мертвых	\N	Ива́н Серге́евич Шмелёв (21 сентября [3 октября] 1873, Москва, Российская империя — 24 июня 1950, Покровский монастырь, Бюсси-ан-От, Франция) — русский писатель, публицист, православный мыслитель.\n	{"Ужасы и мистика"}
389	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Демоны ночи	\N	Лили́т (ивр. ‏לִילִית‏‎) — демоница в еврейской мифологии. В каббалистической теории — первая жена Адама.\n	{"Ужасы и мистика"}
395	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Бешеный	\N	\N	{"Ужасы и мистика"}
398	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Серебряная пуля	\N	\N	{"Ужасы и мистика"}
284	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Заклинательницы ветров	\N	\N	{Фэнтези}
285	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Миссия Шута	\N	\N	{Фэнтези}
405	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Лангольеры	\N	«Ланголье́ры» (англ. The Langoliers) — повесть американского писателя Стивена Кинга, написанная в жанрах психологического ужаса и фантастики, впервые опубликованная в 1990 году в сборнике «Четыре после полуночи». Согласно основной сюжетной линии, несколько человек во время полёта на Boeing 767 просыпаются и понимают, что остальные пассажиры, включая пилотов и членов экипажа, исчезли, а самолётом управляет автопилот. Группе выживших нужно не только разобраться в происходящем, но и спастись от лангольеров — кошмарных зубастых существ, пожирающих пространство. Произведение развилось от центрального образа — женщины, закрывающей рукой трещину в пассажирском авиалайнере.\n	{"Ужасы и мистика"}
434	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 05 Интерлюдия Томаса (пер. Валерий Ледовской )	\N	\N	{"Ужасы и мистика"}
288	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ученик убийцы	\N	\N	{Фэнтези}
289	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Странствия убийцы	\N	\N	{Фэнтези}
290	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Королевский убийца	\N	\N	{Фэнтези}
436	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 05 Интерлюдия Томаса	\N	\N	{"Ужасы и мистика"}
437	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 01 Странный Томас	\N	\N	{"Ужасы и мистика"}
457	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Нехорошее место (пер. Вебер)	\N	\N	{"Ужасы и мистика"}
294	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Драконья Гавань	\N	\N	{Фэнтези}
506	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Ребенок-демон (Дитя Зверя)	\N	\N	{"Ужасы и мистика"}
296	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кровь драконов	\N	\N	{Фэнтези}
528	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Законы заблуждений	\N	Трилогия была выпущена в издательствах Victor Gollancz в Великобритании и Pyr в США.\n	{Фантастика}
530	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Время вестников	\N	\N	{Фантастика}
534	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Эликсиры Сатаны	\N	\N	{Фантастика}
535	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Щелкунчик и мышиный король	\N	«Щелкунчик и Мышиный король» (нем. Nußknacker und Mausekönig) — рождественская повесть-сказка Эрнста Теодора Амадея Гофмана, опубликованная в сборнике «Детские сказки» (Берлин, 1816) и включённая в книгу «Серапионовы братья» («Serapionsbrüder», 1819). Произведение было написано под влиянием общения автора с детьми своего товарища Юлиана Гитцига; их имена — Фриц и Мари — получили главные герои «Щелкунчика». По мотивам сказки был создан балет Петра Чайковского в двух актах на либретто Мариуса Петипа. Произведение было неоднократно экранизировано и стало основой для мультипликационных фильмов.\n	{Фантастика}
536	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Житейские воззрения кота Мурра	\N	«Жите́йские воззре́ния Кота́ Му́рра вку́пе с фрагме́нтами биогра́фии капельме́йстера Иога́ннеса Кре́йслера, случа́йно уцеле́вшими в макулату́рных листа́х» (нем. Lebens-Ansichten des Katers Murr nebst fragmentarischer Biographie des Kapellmeisters Johannes Kreisler in zufälligen Makulaturblättern) — сатирический роман немецкого писателя-романтика Э. Т. А. Гофмана, вышедший в двух томах в 1819 и 1821 годах. Произведение считается вершиной творчества писателя, объединяя в себе смешное и трагическое.\n	{Фантастика}
537	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Понедельник начинается в субботу	\N	\N	{Фантастика}
538	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Улитка на склоне	\N	Сами авторы считали его самым совершенным и самым значительным своим произведением[3].\n	{Фантастика}
539	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Смерть и дева	\N	«Смерть и де́ва» (англ. Death and the Maiden) — камерный остросюжетный кинофильм режиссёра Романа Полански, вышедший на экраны в 1994 году. Экранизация пьесы Ариэля Дорфмана, чилийского драматурга, выжившего в концлагере Пиночета. Главные и фактически единственные роли исполнили Сигурни Уивер, Стюарт Уилсон и Бен Кингсли.\n	{Фантастика}
303	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Город падших ангелов	\N	Серия книг стала одной из самых популярных среди подросткового литературного жанра паранормальной романтики или городской фантастики. Однако сама Клэр изначально не собиралась писать серию для подростков, произведение должно было стать фантастическим романом, в котором главные герои — подростки. Когда же издательство изъявило желание увидеть описание процесса взросления персонажей, Кассандра Клэр заявила, что она «хотела рассказать историю о людях, переживающих важнейший этап между юностью и взрослой жизнью, когда каждый шаг определяет, каким человеком ты станешь, а не отражает того, кем ты уже являешься.»[1] Решение представить её романы как подростковую литературу сделало книги Клэр бестселлерами, а Хронику сумеречных охотников — самой популярной среди молодой аудитории.\n	{Фэнтези}
543	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Призраки нового замка	\N	Джин Родман Вулф (англ. Gene Wolfe; 7 мая 1931 — 14 апреля 2019[6]) — американский писатель, писавший в жанрах научной фантастики и фэнтези.\n	{Фантастика}
305	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Город стекла	\N	\N	{Фэнтези}
306	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Город костей	\N	\N	{Фэнтези}
544	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Земляне	\N	\N	{Фантастика}
546	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Здесь водятся тигры	\N	\N	{Фантастика}
309	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мертвым сном	\N	\N	{Фэнтези}
310	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мертвы, пока светло	\N	В книге рассказывается о знакомстве официантки Соки Стакхаус и вампира Билла Комптона, вспыхнувшей между ними любви и первом совместном расследовании.\n	{Фэнтези}
311	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Живые мертвецы в Далласе	\N	\N	{Фэнтези}
548	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Канун всех святых	\N	Бородино́ — деревня в Можайском районе Московской области, административный центр сельского поселения Бородинское[2].\n	{Фантастика}
313	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сплошь мертвецы	\N	\N	{Фэнтези}
549	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	И всё-таки наш	\N	\N	{Фантастика}
315	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Записки юного врача	\N	\N	{Фэнтези}
550	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	451 градус по Фаренгейту	\N	«451 градус по Фаренгейту» (англ. Fahrenheit 451) — научно-фантастический роман-антиутопия Рэя Брэдбери, изданный в 1953 году. Роман описывает американское общество близкого будущего, в котором книги находятся под запретом; «пожарные»[1], к числу которых принадлежит и главный герой Гай Монтэг, сжигают любые найденные книги. В ходе романа Монтэг разочаровывается в идеалах общества, частью которого он является, становится изгоем и присоединяется к небольшой подпольной группе маргиналов, сторонники которой заучивают тексты книг, чтобы спасти их для потомков. Название книги объясняется в эпиграфе: «451 градус по Фаренгейту — температура, при которой воспламеняется и горит бумага»[2]. В книге содержится немало цитат из произведений англоязычных авторов прошлого (таких, как Уильям Шекспир, Джонатан Свифт и другие), а также несколько цитат из Библии.\n	{Фантастика}
563	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Одержимый магией	\N	Логическим продолжением романа является книга «Одержимый магией»\n	{Фантастика}
406	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Армагеддон	\N	\N	{"Ужасы и мистика"}
407	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Куджо	\N	\N	{"Ужасы и мистика"}
408	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Невинность	\N	\N	{"Ужасы и мистика"}
409	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Безжалостный	\N	\N	{"Ужасы и мистика"}
602	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Куколка	\N	\N	{Фантастика}
551	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Марсианские хроники	\N	Фактически содержание книги представляет собой нечто среднее между собранием коротких историй и эпизодических новелл, включая ранее опубликованные в литературных журналах во второй половине 1940-х годов рассказы. В «Марсианских хрониках» отражены основные проблемы, волнующие американское общество в начале 1950-х годов: угроза ядерной войны, тоска по более простой жизни, реакции против расизма и цензуры. Жанр научной фантастики нравился Брэдбери именно возможностью показать существующее положение дел в мире, используя для этого декорации вымышленного будущего, и таким образом оградить людей от повторения и усугубления ошибок прошлого.\n	{Фантастика}
552	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вино из одуванчиков	\N	«Винo из одуванчиков» (англ. Dandelion Wine) — повесть Рэя Брэдбери, впервые изданная в 1957 году.\n	{Фантастика}
553	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Лёд и пламя	\N	«Песнь льда и огня» (англ. A Song of Ice and Fire, другой вариант перевода — «Песнь льда и пламени») — серия фэнтези-романов американского писателя и сценариста Джорджа Р. Р. Мартина. Мартин начал писать эту серию в 1991 году. Изначально задуманная как трилогия, к настоящему моменту она разрослась до пяти опубликованных томов, и ещё два находятся в проекте. Автором также написаны повести-приквелы и серия повестей, представляющих собой выдержки из основных романов серии. Одна из таких повестей, «Кровь дракона», была удостоена Премии Хьюго[1]. Три первых романа серии были награждены премией «Локус» за лучший роман фэнтези в 1997, 1999 и 2001 годах соответственно.\n	{Фантастика}
318	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Хокку	\N	Ха́йку (яп. 俳句) — жанр традиционной японской лирической поэзии вака, известный с XIV века. В самостоятельный жанр эта поэзия, носившая тогда название хокку, выделилась в XVI веке; современное название было предложено в XIX веке поэтом Масаока Сики[1]. Поэт, пишущий хайку, называется хайдзин (яп. 俳人). Одним из самых известных представителей жанра был и до сих пор остаётся Мацуо Басё.\n	{Поэзия}
555	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Метро 2034	\N	\N	{Фантастика}
556	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дневник ученого	\N	Дми́трий Алексе́евич Глухо́вский (род. 12 июня 1979[1][2], Москва) — российский писатель, журналист, сценарист, радиоведущий и военный корреспондент.\n	{Фантастика}
321	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ромео и Джульетта	\N	\N	{Поэзия}
560	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Проект Румоко	\N	«Вспышка» (англ. Flare) — научно-фантастический роман, написанный в 1992 году Роджером Желязны и Томасом Трастоном Томасом. Действия романа отсылает нас к 2081 году, когда в результате доселе невиданной вспышки на Солнце, Человечество переживает серию катастроф. Книга разбита на короткие отрывки, которые описывают действия различных людей в момент катаклизма. На русском языке впервые опубликовано издательством Полярис в 12-м томе «Миров Роджера Желязны»[1].\n	{Фантастика}
571	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Остров мертвых	\N	«Остров мёртвых» (англ. Isle of the Dead) — роман американского писателя Роджера Желязны, вышедший в 1969.\nНоминирован в 1969 году на премию Небьюла за лучший роман[1], в 1972 году получил французскую премию Аполло[2].\n	{Фантастика}
324	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Про Федота стрельца	\N	«Про Федота-стрельца, удалого молодца» — пьеса и наиболее известное поэтическое произведение Леонида Филатова, написанная по мотивам русской народной сказки «Поди туда — не знаю куда, принеси то — не знаю что[en]». Впервые опубликована в журнале «Юность», 1987 год, № 3. Сразу обрела популярность, а использование сказочных персонажей в сочетании с яркой речью Филатова и жёсткими сатирическими замечаниями способствовало успеху.\n	{Юмор}
574	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ружья Авалона	\N	\N	{Фантастика}
577	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Принц Хаоса	\N	На русский язык в разное время роман переводили: Ян Юа, Е. Волковыский, Н. Белякова, Т. Источникова, Е. Доброхотова-Майкова, Р. Ольшевский.\n	{Фантастика}
582	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	31 июня	\N	\N	{Фантастика}
328	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дневник Домового. Рассказы с чердака	\N	\N	{Юмор}
329	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Манюня	\N	\N	{Юмор}
410	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Психоделические дети	\N	\N	{"Ужасы и мистика"}
411	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Скорость	\N	\N	{"Ужасы и мистика"}
412	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Убивающие взглядом	\N	\N	{"Ужасы и мистика"}
583	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Голова профессора Доуэля	\N	\N	{Фантастика}
584	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ариэль	\N	«Ариэ́ль» — последний научно-фантастический роман Александра Беляева, изданный в 1941 году\n	{Фантастика}
585	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Остров погибших кораблей	\N	\N	{Фантастика}
587	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Человек-амфибия	\N	«Челове́к-амфи́бия» — научно-фантастический роман о человеке, способном жить под водой, написанный Александром Беляевым в 1927 году.\n	{Фантастика}
588	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Богадельня	\N	\N	{Фантастика}
592	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пять минут взаймы	\N	Дэвид Левитан (англ. David Levithan; род. 7 сентября 1972) — американский писатель, известный своими романами для подростков, некоторые из которых входили в список бестселлеров по версии The New York Times, три были экранизированы.\n	{Фантастика}
596	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Восьмой круг подземки	\N	\N	{Фантастика}
597	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Разорванный круг	\N	Растич говорит следующее: «Альбом во всех отношениях тяжёлый. Записывали его вдалеке от дома, в Питере на „Добролёте“ с помощью лучших, на мой взгляд, звукорежиссёров страны — Андрея Алякринского и Александра Мартисова. Когда над ним работали, казалось, что действительно проходим через первый круг ада, — столько было конфликтов, неприятных событий и разочарований в близких людях. Мне постоянно казалось, что мы вот-вот распадёмся как группа. Но мы все-таки выстояли, благодаря, наверное, какому-то отчаянию, которого в альбоме, кстати, очень много. Выпустили его на своем лейбле (точнее, на лейбле нашего басиста Егора) „Indie-Go!“. Это такая небольшая компания, издающая, в основном, друзей — „Седьмая раса“, „Джан ку“, „Мои ракеты вверх“, „Небо здесь“…»[источник не указан 3839 дней]\n	{Фантастика}
333	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Наши в Турции	\N	Русские в Турции (тур. Türkiye'de Ruslar) — группа русских, проживающая на территории Турции, преимущественно женщины. По вероисповеданию — в основном православные христиане. Говорят на русском и турецком языках. Посол Российской Федерации в Турецкой Республике Владимир Ивановский в 2009 году оценил число русских в Турции в 50 тысяч человек[2]. По неофициальным данным, численность русских в Турции составляет от 300[3] до 500[4] тыс. человек. Все они, за редким исключением, являются гражданами России и стран СНГ. Проживают в основном в Стамбуле, Анталье, Измире, Анкаре, Денизли.\n	{Юмор}
334	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дневник Васи Пупкина	\N	\N	{Юмор}
599	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Реквием по мечте	\N	\N	{Фантастика}
601	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Анабель-Ли	\N	Как утверждает один из биографов По, Аллен Герви, 26 сентября 1849 года Эдгар Аллан По навестил редактора Southern Literary Messenger Томпсона. Гарви так описывает их встречу:\n\n	{Фантастика}
337	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Избранные страницы	\N	\N	{Юмор}
338	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Анекдоты и тосты	\N	В качестве алгоритма формы выступает пародическое использование, имитация исторических преданий, легенд, натуральных очерков и т. п. В ходе импровизированных семиотических преобразований[2] рождается текст, который, вызывая катарсис, доставляет эстетическое удовольствие. Упрощённо говоря, анекдот — это бессознательно проступающее детское речевое творчество. Возможно, отсюда характерное старинное русское название — байка[3].\n	{Юмор}
339	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Все афоризмы	\N	В афоризме достигается предельная концентрация непосредственного сообщения и того контекста, в котором мысль воспринимается окружающими слушателями или читателем.\n	{Юмор}
340	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Смех сквозь слезы	\N	\N	{Юмор}
604	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кукольник	\N	Па́вел Васи́льевич Ку́кольник (24 июня (5 июля) 1795, Замосць, Речь Посполита — 3 (15) сентября 1884, Вильно, Российская империя) — виленский историк, поэт, педагог, литератор, драматург. Сын профессора В. Г. Кукольника; старший брат Нестора и Платона Кукольников.\n	{Фантастика}
343	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Я люблю Америку	\N	«Одноэтажная Америка» — книга в жанре путевого очерка, написанная Ильёй Ильфом и Евгением Петровым в конце 1935 и в течение 1936 года[1]. Книга издана в 1937 году в Советском Союзе[2]. После 1947 года, в связи с началом кампании по «борьбе с низкопоклонством перед Западом» и антиамериканским вектором советской внешней политики, книгу изъяли из общественного доступа и поместили в спецхран[3]. За цитирование книги или отдельных её фрагментов стали отправлять в лагеря по статье «контрреволюционная пропаганда или агитация».[4] После смерти Сталина, в годы хрущёвской оттепели книга вновь появилась в открытом доступе, как и другие произведения Ильфа и Петрова.\n	{Юмор}
413	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Звереныш (Вестник смерти)	\N	\N	{"Ужасы и мистика"}
414	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Ключи к полуночи	\N	\N	{"Ужасы и мистика"}
415	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Подозреваемый (Муж)	\N	\N	{"Ужасы и мистика"}
606	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сказки дедушки-вампира	\N	«Академия вампиров» (англ. Vampire Academy) — серия романтических книг о вампирах, созданная американской писательницей Райчел Мид. Первый роман был опубликован в 2007 году. В них описываются приключения семнадцатилетней девушки-дампира Розмари Хэзевей, которая обучается на специальность телохранителя для своей подруги, принцессы Лиссы, в вампирской школе — Академии св. Владимира.\n	{Фантастика}
348	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дживс, вы - гений	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
349	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дживс шевелит мозгами	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
350	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дживс и неумолимый	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
351	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Так держать, дживс	\N	\N	{Юмор}
352	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Свадебные колокола отменются	\N	\N	{Юмор}
353	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Командует парадом Дживс	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
354	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Товарищь Бинго	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
355	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Тысяча благодарностей, Дживс	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
356	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Этот неподражаемый Дживс	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
357	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Полный порядок, Дживс	\N	\N	{Юмор}
416	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Затаив дыхание	\N	\N	{"Ужасы и мистика"}
417	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Голос ночи	\N	\N	{"Ужасы и мистика"}
418	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Ледяная тюрьма	\N	\N	{"Ужасы и мистика"}
608	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Коган-варвар	\N	Ко́нан (англ. Conan) — вымышленный воин-варвар из Киммерии, придуманный Робертом Ирвином Говардом в цикле повестей о Хайборийской Эре, написанных в жанре фэнтези и издававшихся в журнале «Weird Tales». Персонаж книг, комиксов, кинофильмов и компьютерных игр, один из наиболее популярных фантастических персонажей XX века.\n	{Фантастика}
358	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дживс уходит на каникулы	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
359	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Бинго.Не везет в Гудвуде	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
360	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дживс и скользский тип	\N	\N	{Юмор}
361	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Без замены штрафом	\N	\N	{Юмор}
362	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дживс готовит омлет	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
363	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Шалости аристократов	\N	\N	{Юмор}
612	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кино до гроба	\N	Андре́й Петро́вич Звя́гинцев (род. 6 февраля 1964, Новосибирск) — российский кинорежиссёр и сценарист. Обладатель главного приза Венецианского и лауреат Каннского кинофестивалей. Двукратный номинант на премию «Оскар» в категории «Лучший фильм на иностранном языке» (2015, 2018) за фильмы «Левиафан» (2014) и «Нелюбовь» (2017).\n	{Фантастика}
365	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дживс и дух Рождества	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
366	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Фамильная честь Вустеров	\N	\N	{Юмор}
367	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ваша взяла, Дживс	\N	\N	{Юмор}
368	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Брачный сезон	\N	«Расторже́ние бра́ка» — книга британского писателя и богослова К. С. Льюиса, в которой он описывает своё видение христианской концепции рая и ада.\n	{Юмор}
369	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Секретарь министра	\N	FictionBook is an open XML-based e-book format which originated and gained popularity in Russia. FictionBook files have the .fb2 filename extension. Some readers also support ZIP-compressed FictionBook files (.fb2.zip or .fbz)\n	{Юмор}
370	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кодекс чести Вустеров	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
371	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вперед, Дживс	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
419	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Помеченный смертью	\N	\N	{"Ужасы и мистика"}
420	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Улица Теней, 77	\N	\N	{"Ужасы и мистика"}
614	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Перекресток	\N	«Перекрёсток» —  российская сеть супермаркетов, которой управляет X5 Retail Group.\n	{Фантастика}
621	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Конец главы	\N	\N	{Приключения}
622	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения барона Мюнхаузена	\N	\N	{Приключения}
623	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Записки о Шерлоке Холмсе	\N	\N	{Приключения}
624	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Затерянный мир	\N	\N	{Приключения}
372	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Не позвать ли нам Дживса	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
373	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Находчивость Дживса	\N	Джи́вс и Ву́стер — популярный цикл комедийных романов и рассказов английского писателя П. Г. Вудхауза о приключениях молодого английского аристократа Берти Вустера и его камердинера Дживса. Цикл в основном написан в период с 1916 по 1930 год, а затем он дополнялся единичными произведениями вплоть до 1974 года. Романы и рассказы в основном написаны в жанре комедии положений.\n	{Юмор}
625	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Одиссея капитана Блада	\N	\N	{Приключения}
650	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Правда и вымысел	\N	\N	{Приключения}
376	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Одиссея	\N	\N	{Мифы,легенды}
377	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Одиссея	\N	\N	{"Старинная литература"}
626	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Над кукушкиным гнездом	\N	«Над кукушкиным гнездом» («Полёт над гнездом кукушки», «Пролетая над гнездом кукушки», англ. One Flew Over the Cuckoo's Nest) — роман Кена Кизи (1962). Считается[кем?] одним из главных литературных произведений движений битников и хиппи.[источник не указан 618 дней] Существует несколько переводов романа на русский язык.\n	{Приключения}
379	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дом страха	\N	\N	{"Ужасы и мистика"}
380	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Иствикские ведьмы	\N	\N	{"Ужасы и мистика"}
627	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Жизнь и удивительные приключения Робинзона Крузо	\N	«Робинзо́н Кру́зо» (англ. Robinson Crusoe)[Комм. 1] — роман английского писателя Даниэля Дефо (1660—1731), впервые опубликованный в апреле 1719 года, повествующий о нравственном возрождении человека в общении с природой[1] и обессмертивший имя автора[2]. Написан как автобиография морского путешественника и плантатора Робинзона Крузо, желавшего ещё более разбогатеть скорым и нелегальным путём, но в результате кораблекрушения попавшего на необитаемый остров, где провёл 28 лет. Сам Дефо называл свой роман аллегорией[3].\n	{Приключения}
382	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Город теней	\N	«Чёрный отря́д» (англ. the Black Company) — серия из одиннадцати романов в жанре тёмного фэнтези, написанная Гленом Куком в период с 1984 по 2018 годы. Серия рассказывает об истории отряда наёмников — Чёрного Отряда.\n	{"Ужасы и мистика"}
383	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пригоршня тьмы	\N	\N	{"Ужасы и мистика"}
628	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Рождественская песнь	\N	«Рожде́ственская песнь в про́зе: свя́точный расска́з с привиде́ниями» (англ. A Christmas Carol in Prose, Being a Ghost Story of Christmas), обычно называемая просто «Рожде́ственская песнь» (англ. A Christmas Carol) — повесть-сказка британского писателя Чарльза Диккенса, вышедшая в 1843 году. Состоит из пяти глав, называемых автором «строфами».\n	{Приключения}
385	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Черное дело	\N	\N	{"Ужасы и мистика"}
386	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Псы Вавилона	\N	\N	{"Ужасы и мистика"}
421	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Слезы дракона	\N	\N	{"Ужасы и мистика"}
422	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Единственный выживший	\N	\N	{"Ужасы и мистика"}
629	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Домби и сын	\N	«До́мби и сын» (англ. Dombey and Son) — роман английского писателя Чарльза Диккенса. Впервые публиковался частями ежемесячно в период с 1 октября 1846 года по 1 апреля 1848 года и одним томом в 1848 году, с иллюстрациями Хабло Найта Брауна.\n	{Приключения}
631	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	В глуби веков	\N	Любо́вь Фёдоровна Воронко́ва (1906 — 1976) — советская писательница, автор многих детских книг и цикла исторических повестей для детей. Член Союза писателей СССР.\n	{Приключения}
633	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Алмаз Раджи	\N	«Клуб самоуби́йц, или Приключе́ния титуло́ванной осо́бы» — приключенческий трёхсерийный телефильм по мотивам двух циклов повестей Р. Л. Стивенсона «Клуб самоубийц» и «Алмаз раджи». На телеэкраны вышел в январе 1981 года (хотя полностью готов был уже в 1979 году), под названием «Приключения принца Флоризеля». Оригинальное название и оригинальные титры, открывающие каждую серию фильма, были возвращены в 1990-х годах.\n	{Приключения}
387	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Аватар бога	\N	Авата́ра[1] (санскр. अवतार, avatāra IAST, «нисхождение») — термин в философии индуизма, обычно используемый для обозначения нисхождения божества на землю, его воплощение в человеческом облике[2][3] (в частности в вайшнавизме нисхождение Вишну из Вайкунтхи). Хотя на русский язык слово «аватара» обычно переводится как «воплощение», точнее его можно перевести как «явление» или «проявление», так как концепция аватары заметно отличается от идеи воплощения Бога «во плоти» в христианстве[4][5].\n	{"Ужасы и мистика"}
634	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Странная история доктора Джекила и мистера Хайда	\N	Прототипом главного героя стали известные шотландские преступники, которые вели двойную жизнь: Томас Вейр[6] и Уильям Броди[7], а общим фоном — городские легенды и исторические пейзажи Эдинбурга.\n	{Приключения}
679	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Трое в лодке (не считая собаки)	\N	\N	{Приключения}
390	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дно разума	\N	\N	{"Ужасы и мистика"}
391	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мара	\N	Кни́га — один из видов печатной продукции: непериодическое издание, состоящее из сброшюрованных или отдельных бумажных листов (страниц) или тетрадей, на которых нанесена типографским или рукописным способом текстовая и графическая (иллюстрации) информация, имеющее, как правило, твёрдый переплёт[1].\n	{"Ужасы и мистика"}
392	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Карты Люцифера	\N	\N	{"Ужасы и мистика"}
393	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Девятая жизнь нечисти	\N	\N	{"Ужасы и мистика"}
638	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Три мушкетера	\N	«Три мушкетёра» (фр. Les trois mousquetaires) — историко-приключенческий роман Александра Дюма-отца, впервые опубликованный в парижской газете Le Siècle в 1844 году с 14 марта по 11 июля. Книга посвящена приключениям молодого дворянина по имени д’Артаньян, отправившегося в Париж, чтобы стать мушкетёром, и трёх его друзей-мушкетёров Атоса, Портоса и Арамиса в период между 1625 и 1628 годами.\n	{Приключения}
639	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Асканио	\N	\N	{Приключения}
396	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Холодный человек	\N	\N	{"Ужасы и мистика"}
397	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кровавый шабаш	\N	\N	{"Ужасы и мистика"}
641	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Человек, который смеется	\N	\N	{Приключения}
399	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Скорпион нападает первым	\N	\N	{"Ужасы и мистика"}
400	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Обреченный пророк	\N	\N	{"Ужасы и мистика"}
401	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Долгая прогулка	\N	\N	{"Ужасы и мистика"}
402	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Талисман	\N	\N	{"Ужасы и мистика"}
403	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Воспламеняющая взглядом	\N	«Воспламеня́ющая взгля́дом» (англ. Firestarter, дословно: Поджигательница, 1980) — фантастический роман Стивена Кинга о девочке, обладающей даром пирокинеза. Был номинирован на премию Британская премия фэнтези, Локус и Балрог как лучший роман. В 1984 вышла одноименная экранизация.\n	{"Ужасы и мистика"}
404	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Черный дом	\N	\N	{"Ужасы и мистика"}
642	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Отверженные	\N	«Отве́рженные» (фр. «Les Misérables») — роман-эпопея французского классика Виктора Гюго. Широко признан мировой литературной критикой и мировой общественностью апофеозом творчества писателя и одним из величайших романов XIX столетия. Впервые опубликован в 1862 году.\n	{Приключения}
643	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Собор Парижской Богоматери	\N	«Собо́р Пари́жской Богома́тери» (фр. Notre-Dame de Paris) — роман Виктора Гюго, опубликованный в марте 1831 года. Первый исторический роман на французском языке. Одно из наиболее известных произведений Гюго, роман был переведён на множество языков, неоднократно экранизирован, по нему поставлены оперы и балет, спектакли и мюзикл.\n	{Приключения}
644	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Белый клык	\N	«Белый Клык» (англ. White Fang) — приключенческая повесть Джека Лондона, главным героем которой является полусобака-полуволк по кличке Белый Клык. Впервые произведение опубликовано в нескольких номерах журнала The Outing Magazine с мая по октябрь 1906 года.\n	{Приключения}
646	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Покаяние пророков	\N	Сергей Трофимович Алексеев (род. 20 января 1952 года) — российский писатель национал-патриотического направления. Творчество оказало влияние на развитие идей родноверия (славянского неоязычества)[2]. Член Союза писателей России[1].\n	{Приключения}
431	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 04 Ночь Томаса	\N	\N	{"Ужасы и мистика"}
432	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 03 Демоны пустыни, или Брат Томас	\N	\N	{"Ужасы и мистика"}
433	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 02 Казино смерти	\N	\N	{"Ужасы и мистика"}
647	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Звездные раны	\N	Сергей Трофимович Алексеев (род. 20 января 1952 года) — российский писатель национал-патриотического направления. Творчество оказало влияние на развитие идей родноверия (славянского неоязычества)[2]. Член Союза писателей России[1].\n	{Приключения}
435	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 07 Судьба Томаса, или Наперегонки со смертью	\N	\N	{"Ужасы и мистика"}
649	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Хранитель Силы	\N	Сергей Трофимович Алексеев (род. 20 января 1952 года) — российский писатель национал-патриотического направления. Творчество оказало влияние на развитие идей родноверия (славянского неоязычества)[2]. Член Союза писателей России[1].\n	{Приключения}
652	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Страга Севера	\N	Сергей Трофимович Алексеев (род. 20 января 1952 года) — российский писатель национал-патриотического направления. Творчество оказало влияние на развитие идей родноверия (славянского неоязычества)[2]. Член Союза писателей России[1].\n	{Приключения}
438	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Полночь	\N	\N	{"Ужасы и мистика"}
439	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Видение	\N	\N	{"Ужасы и мистика"}
440	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Дьявольское семя (Помеченный смертью)	\N	\N	{"Ужасы и мистика"}
441	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Нехорошее место	\N	\N	{"Ужасы и мистика"}
442	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Душа в лунном свете	\N	\N	{"Ужасы и мистика"}
443	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Эшли Белл	\N	\N	{"Ужасы и мистика"}
444	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Призрачные огни (Огни теней)	\N	\N	{"Ужасы и мистика"}
445	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Невероятный дубликат	\N	\N	{"Ужасы и мистика"}
446	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Тьма под солнцем	\N	\N	{"Ужасы и мистика"}
447	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Предсказание	\N	\N	{"Ужасы и мистика"}
448	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Очарованный кровью	\N	\N	{"Ужасы и мистика"}
449	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Ложная память	\N	\N	{"Ужасы и мистика"}
450	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Славный парень	\N	\N	{"Ужасы и мистика"}
451	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Темные реки сердца	\N	\N	{"Ужасы и мистика"}
452	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Фантомы	\N	\N	{"Ужасы и мистика"}
453	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - При свете луны	\N	\N	{"Ужасы и мистика"}
454	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Чейз (Погоня)	\N	\N	{"Ужасы и мистика"}
455	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Покровитель (Молния)	\N	\N	{"Ужасы и мистика"}
456	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - До рая подать рукой	\N	\N	{"Ужасы и мистика"}
653	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Молчание пирамид	\N	Сергей Трофимович Алексеев (род. 20 января 1952 года) — российский писатель национал-патриотического направления. Творчество оказало влияние на развитие идей родноверия (славянского неоязычества)[2]. Член Союза писателей России[1].\n	{Приключения}
458	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Шоу смерти (Вызов смерти)	\N	\N	{"Ужасы и мистика"}
459	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Сумеречный взгляд	\N	\N	{"Ужасы и мистика"}
460	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Ночной кошмар (Властители душ)	\N	\N	{"Ужасы и мистика"}
461	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 1 Кровавый риск	\N	\N	{"Ужасы и мистика"}
462	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 2 Врата Ада	\N	\N	{"Ужасы и мистика"}
463	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Зимняя луна (Ад в наследство)	\N	\N	{"Ужасы и мистика"}
464	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Кукольник	\N	\N	{"Ужасы и мистика"}
465	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Руки Олли	\N	\N	{"Ужасы и мистика"}
466	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Краем глаза	\N	\N	{"Ужасы и мистика"}
467	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Античеловек	\N	\N	{"Ужасы и мистика"}
516	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Вестник смерти	\N	\N	{"Ужасы и мистика"}
517	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Крыса из нержавеющей стали призвана в армию	\N	\N	{Фантастика}
518	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Стальная крыса на манеже	\N	\N	{Фантастика}
519	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Крыса из нержавеющей стали спасает мир	\N	\N	{Фантастика}
468	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Лицо страха (По прозвищу «мясник»)	\N	В каждой из книг описывается один день, в течение которого главный герой трилогии, прославленный герой и музыкант Квоут (Kvothe), рассказывает Девану Локиизу (Devan Lochees), известному как Хронист, часть истории своей жизни. Иногда рассказ Квоута перебивается интерлюдиями, дающими некоторое представление о том, что происходит в настоящем. Интерлюдии написаны в третьем лице, рассказывает же Квоут о своём прошлом, разумеется, в первом лице.\n	{"Ужасы и мистика"}
469	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Ангелы-хранители	\N	\N	{"Ужасы и мистика"}
470	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 2 Скованный ночью	\N	\N	{"Ужасы и мистика"}
471	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 1 Живущий в ночи	\N	\N	{"Ужасы и мистика"}
472	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Дверь в декабрь	\N	\N	{"Ужасы и мистика"}
473	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Душа тьмы	\N	\N	{"Ужасы и мистика"}
474	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Маска	\N	\N	{"Ужасы и мистика"}
475	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Дом ужасов	\N	\N	{"Ужасы и мистика"}
476	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Гиблое место	\N	\N	{"Ужасы и мистика"}
477	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Черные реки сердца	\N	\N	{"Ужасы и мистика"}
478	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Незнакомцы (Красная луна)	\N	\N	{"Ужасы и мистика"}
479	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Симфония тьмы	\N	\N	{"Ужасы и мистика"}
480	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Тик-так	\N	\N	{"Ужасы и мистика"}
481	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Провал в памяти	\N	\N	{"Ужасы и мистика"}
482	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Багровая ведьма	\N	\N	{"Ужасы и мистика"}
483	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Глаза тьмы	\N	\N	{"Ужасы и мистика"}
484	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Вторжение	\N	\N	{"Ужасы и мистика"}
485	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Лицо в зеркале	\N	\N	{"Ужасы и мистика"}
486	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Мутанты (Звездный поиск)	\N	\N	{"Ужасы и мистика"}
487	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Дети бури	\N	\N	{"Ужасы и мистика"}
488	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 1 Блудный сын	\N	\N	{"Ужасы и мистика"}
489	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 3 Мертвый и живой	\N	\N	{"Ужасы и мистика"}
490	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 5 Город мёртвых	\N	\N	{"Ужасы и мистика"}
491	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 2 Город Ночи	\N	\N	{"Ужасы и мистика"}
492	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц 4 Потерянные души	\N	\N	{"Ужасы и мистика"}
493	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Город (сборник)	\N	\N	{"Ужасы и мистика"}
494	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Наследие страха	\N	\N	{"Ужасы и мистика"}
495	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Дом Грома	\N	\N	{"Ужасы и мистика"}
496	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Отродье ночи (Шорохи)	\N	\N	{"Ужасы и мистика"}
497	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Сошествие тьмы (Надвигается тьма)	\N	\N	{"Ужасы и мистика"}
498	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Холодный огонь	\N	\N	{"Ужасы и мистика"}
499	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Путь из ада (Врата ада)	\N	\N	{"Ужасы и мистика"}
500	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Ледяное пламя	\N	\N	{"Ужасы и мистика"}
501	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Логово (Прятки)	\N	\N	{"Ужасы и мистика"}
502	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Мышка за стенкой скребется всю ночь	\N	\N	{"Ужасы и мистика"}
503	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Твое сердце принадлежит мне	\N	\N	{"Ужасы и мистика"}
504	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Мистер Убийца	\N	\N	{"Ужасы и мистика"}
505	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Неведомые дороги (сборник)	\N	\N	{"Ужасы и мистика"}
507	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ткачев - Дин Кунц	\N	\N	{"Ужасы и мистика"}
508	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Самый темный вечер в году	\N	\N	{"Ужасы и мистика"}
509	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Исступление. Скорость (сборник)	\N	\N	{"Ужасы и мистика"}
510	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Двенадцатая койка	\N	\N	{"Ужасы и мистика"}
511	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Ясновидящий	\N	\N	{"Ужасы и мистика"}
512	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Шорохи (Отродье ночи)	\N	\N	{"Ужасы и мистика"}
513	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Вызов смерти	\N	\N	{"Ужасы и мистика"}
514	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Человек страха	\N	\N	{"Ужасы и мистика"}
515	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кунц - Что знает ночь	\N	\N	{"Ужасы и мистика"}
520	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Стальная крыса отправляется в ад	\N	\N	{Фантастика}
521	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Стальную крысу в президенты!	\N	\N	{Фантастика}
522	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Крыса из нержавеющей стали	\N	\N	{Фантастика}
523	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Стальная крыса поет блюз	\N	\N	{Фантастика}
524	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ты нужен стальной крысе	\N	\N	{Фантастика}
525	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Крыса из нержавеющей стали появляется на свет	\N	\N	{Фантастика}
526	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Месть крысы из нержавеющей стали	\N	\N	{Фантастика}
527	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Новые приключения Стальной крысы	\N	\N	{Фантастика}
654	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения Тома Сойера	\N	«Приключе́ния То́ма Со́йера» (англ. The Adventures of Tom Sawyer) — вышедшая в 1876 году повесть Марка Твена о приключениях мальчика, живущего в небольшом американском городке Сент-Питерсберг (Санкт-Петербург) в штате Миссури. Действие в книге происходит до событий Гражданской войны в США, при этом ряд моментов в этой книге и её продолжении, «Приключениях Гекльберри Финна», а также обстоятельства жизни автора, во многом легшие в основу книг, уверенно указывают на первую половину 1840-х годов.\n	{Приключения}
529	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Низвергатели легенд	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Фантастика}
655	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Принц и нищий	\N	«Принц и ни́щий» (англ. The Prince and the Pauper) — исторический роман Марка Твена. Написан писателем в коннектикутском доме и впервые опубликован в 1881 году в Канаде. В романе с иронией описаны недостатки и нелепости несовершенной английской государственной и судебной системы XVI века. Перевод на русский язык Корнея Чуковского и Николая Чуковского многократно переиздавался в СССР.\n	{Приключения}
531	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Творцы апокрифов	\N	\N	{Фантастика}
532	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вестники времен	\N	Андрей Леонидович Мартьянов (род. 3 сентября 1973, Ленинград) — русский писатель, блогер, переводчик фантастических и исторических произведений. Основные жанры — исторические романы, фэнтези, фантастика.\n	{Фантастика}
533	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Большая охота	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Фантастика}
658	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Чингисхан	\N	Чингисха́н (монг. Чингис хаан?, ᠴᠢᠩᠭᠢᠰᠬᠠᠭᠠᠨ? [tʃiŋɡɪs χaːŋ]), собственное имя — Тэмуджин[3][4], Темучин[5][6], Темучжин[7] (монг. Тэмүжин, Тэмүүжин[8]?, ᠲᠡᠮᠦᠵᠢᠨ?) (ок. 1155 или 1162 — август 1227) — основатель и первый великий хан (каган) Монгольской империи, объединивший разрозненные монгольские и тюркские племена; полководец, организовавший завоевательные походы монголов в Китай, Среднюю Азию, на Кавказ и в Восточную Европу. Основатель самой крупной в истории человечества континентальной империи[9].\n	{Приключения}
660	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Юность полководца	\N	Васи́лий Григо́рьевич Ян (настоящая фамилия — Янчеве́цкий; 23 декабря 1874 года (4 января 1875 года), Киев — 5 августа 1954, Звенигород) — русский советский писатель, публицист, поэт и драматург, сценарист, педагог. Автор популярных исторических романов. Сын антиковеда Григория Янчевецкого, брат журналиста и востоковеда Дмитрия Янчевецкого.\n	{Приключения}
661	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Квентин Дорвард	\N	Скотт закончил роман через пять месяцев после окончания предыдущего, «Певерил Пик», и читатели скептически отнеслись к тому, что писатель мог настолько быстро завершить книгу. Вероятно, это была одна из причин медленных продаж на родине писателя.[1] Во Франции, однако, книга произвела фурор, а переводы с французского издания вскоре заполонили всю континентальную Европу.[1]\n	{Приключения}
683	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Копи царя Соломона	\N	«Копи царя Соломона» (англ.  King Solomon's Mines) — викторианский приключенческий роман Генри Райдера Хаггарда (1885), первый из цикла про Аллана Квотермейна.\n	{Приключения}
540	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Золотоглазые	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Фантастика}
541	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Были они смуглые и золотоглазые	\N	Начало «Алой книге» положил Бильбо, описав свой поход в Эребор в 2941 году Третьей Эпохи и назвав эту часть книги «Мои записки. Моё нечаянное путешествие. Туда и потом Обратно и что случилось После». Затем Бильбо дополнил свои записи рассказом о Войне Кольца, добавив к заголовку следующие слова: «Приключения пятерых хоббитов. Повесть о Кольце Всевластья, сочинённая Бильбо Бэггинсом по личным воспоминаниям и по рассказам друзей. Война за Кольцо и наше в ней участие». Кроме того, перу Бильбо принадлежат три тома «Переводов с эльфийского».\n	{Фантастика}
542	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	И камни заговорили	\N	\N	{Фантастика}
662	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Айвенго	\N	«Айве́нго» (англ. Ivanhoe) — один из первых исторических романов. Опубликован в 1819 году как произведение автора «Уэверли» (как позднее выяснилось, Вальтера Скотта). В XIX веке был признан классикой приключенческой литературы. Продажи книги были феноменальными для того времени: первый тираж в 10 тысяч экземпляров был распродан менее, чем за две недели[3]. Успех романа способствовал пробуждению романтического интереса к Средним векам (см. Неоготика).\n	{Приключения}
668	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Французская волчица	\N	Мори́с Самюэ́ль Роже́ Шарль Дрюо́н (фр. Maurice Samuel Roger Charles Druon; 23 апреля 1918 (1918-04-23), Париж, Франция — 14 апреля 2009, там же) — французский писатель, член Французской академии (1967), министр культуры Франции (1973—1974).\n	{Приключения}
545	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Детская площадка	\N	\N	{Фантастика}
673	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Бледный всадник	\N	\N	{Приключения}
547	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Надвигается беда	\N	«Надвигается беда» (англ. Something wicked this way comes; издавался также в переводах «...и духов зла явилась рать», «Что-то страшное грядёт», «Жди дурного гостя»[1]) — роман Рэя Брэдбери, впервые изданный в 1962 году.\n	{Фантастика}
674	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Последнее королевство	\N	В декабре 2015 года сериал был продлён на второй сезон[3], премьера которого состоялась 16 марта 2017 года в США[4][5]. В сентябре 2017 года сериал был продлён на третий сезон[6], который стал доступен эксклюзивно на Netflix 19 ноября 2018 года[7]. В декабре 2018 года сериал был официально продлён на четвёртый сезон[8], съёмки которого завершились в октябре 2019 года[9], а премьера состоялась 26 апреля 2020 года[10].\n	{Приключения}
675	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Песнь небесного меча	\N	Бе́рнард Ко́рнуэлл (англ. Bernard Cornwell, 23 февраля 1944) — английский писатель и репортёр, автор исторических романов про королевского стрелка Ричарда Шарпа.\n	{Приключения}
684	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дочь Монтесумы	\N	Рассказ ведётся от имени англичанина Томаса Вингфилда, который после ряда приключений оказывается в составе испанской экспедиции к берегам Новой Испании, где перед ним открывается экзотический мир ацтеков. Он берёт в жёны дочь императора и осуществляет план возмездия своему давнему противнику.\n	{Приключения}
685	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дети капитана Гранта	\N	«Де́ти капита́на Гра́нта» (фр. Les Enfants du capitaine Grant) — роман французского писателя Жюля Верна, впервые полностью опубликованный в 1868 году, а частями публиковавшийся в «Magasin d'Éducation et de Récréation» (рус. «Журнал воспитания и развлечения»), издававшемся Пьер-Жюлем Этцелем в Париже, с 20 декабря 1865 по 5 декабря 1867 года. Это первая часть трилогии, которую продолжили романы:\n	{Приключения}
564	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Подмененный	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Фантастика}
841	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Берег удачи	\N	\N	{Детектив}
603	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кукольных дел мастер	\N	«Ойкумена» — роман в трёх частях харьковских писателей Дмитрия Громова и Олега Ладыженского, пишущих под псевдонимом Генри Лайон Олди, первая проба пера авторов в жанре «космической оперы». Сами авторы называют своё произведение «Космическая симфония».\n	{Фантастика}
686	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Двадцать тысяч лье под водой	\N	«Два́дцать ты́сяч лье под водо́й»[3], (фр. «Vingt mille lieues sous les mers», дословно — «Двадцать тысяч льё под морями»; в старых русских переводах — «Во́семьдесят ты́сяч вёрст под водо́й», в советских — «80 000 киломе́тров под водо́й»[4]) — классический научно-фантастический роман французского писателя Жюля Верна, впервые опубликованный с 20 марта 1869 по 20 июня 1870 года в журнале «Magasin d’éducation et de récréation»[fr] (рус. «Журнал воспитания и развлечения»), издававшемся Пьер-Жюлем Этцелем в Париже и вышедший отдельным изданием в 1870 году.\n	{Приключения}
687	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Таинственный остров	\N	\N	{Приключения}
688	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Путешествие к центру Земли	\N	«Путешествие к центру Земли» (фр. Voyage au centre de la Terre) — научно-фантастический роман французского писателя Жюля Верна, впервые опубликованный в 1864 году и рассказывающий о путешествии, совершенном группой исследователей в земных недрах.\n	{Приключения}
554	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Метро 2033	\N	In het jaar 2013 heeft een nucleaire oorlog de wereld verwoest. De mensen in Moskou werden gedwongen om te schuilen in hun uitgebreide metrostelsel. Na 20 jaar zijn de stations veranderd in nederzettingen met een eigen politiek. Er vormden zich grote groepen, zoals de 'Rangers' van 'Polis', de Neostalinisten van de 'Red Line' en de Neo-Nazi groep van de 'Fourth Reich'.\n	{Фантастика}
689	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Божественная комедия	\N	«Боже́ственная коме́дия» (итал. La Commedia, позже La Divina Commedia) — поэма, написанная Данте Алигьери в период приблизительно с 1308 по 1321 год[1] и дающая наиболее широкий синтез средневековой культуры и онтологию мира. Настоящая средневековая энциклопедия научных, политических, философских, моральных, богословских знаний[2]. Признаётся величайшим памятником итальянской и мировой культуры.\n	{"Старинная литература"}
690	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Декамерон	\N	«Декамеро́н» (итал. Il Decamerone от др.-греч. δέκα «десять» + ἡμέρα «день»: букв. «Десятиднев») — собрание ста новелл итальянского писателя Джованни Боккаччо, одна из самых знаменитых книг раннего итальянского Ренессанса, написанная приблизительно в 1352—1354 годы. Большинство новелл этой книги посвящено теме любви, начиная от её эротического и заканчивая трагическим аспектами.\n	{"Старинная литература"}
557	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Этот бессмертный	\N	\N	{Фантастика}
558	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мастер снов	\N	Первое издание — в 1966 году. Повесть, на основе которой написан роман, опубликована в 1965 году в журнале «Амейзинг Сториз» под названием «Придающий форму» (He Who Shapes).\n	{Фантастика}
559	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Песнопевец	\N	\N	{Фантастика}
694	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Посмотри на меня	\N	\N	{Романы}
561	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Возвращение палача	\N	\N	{Фантастика}
562	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Здесь водятся драконы	\N	Она представляет собой переосмысление классического латинского выражения Hic sunt leones («тут [водятся] львы»), которым на средневековых картах подписывали неведомые земли на краю ойкумены. Кроме того, в средневековье на многих картах непосредственно изображались фантастические животные, включая драконов. Существует версия, что упоминания драконов может быть связано с варанами комодо на индонезийских островах, рассказы о которых были довольно распространены по всей Восточной Азии[1].\n	{Фантастика}
695	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Время моей Жизни	\N	Джин Родман Вулф (англ. Gene Wolfe; 7 мая 1931 — 14 апреля 2019[6]) — американский писатель, писавший в жанрах научной фантастики и фэнтези.\n	{Романы}
696	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Не верю. Не надеюсь. Люблю	\N	Сеси́лия Ахе́рн (англ. Cecelia Ahern, ирл. Cecelia Ní hEachthairn; род. 30 сентября 1981 года, Дублин, Ирландия) — писательница, автор любовных романов.\n	{Романы}
697	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Там, где ты	\N	«Там, где живут чудовища» — детская книжка с картинками американского писателя и художника Мориса Сендака. Вышла в 1963 году в издательстве «Harper & Row», вскоре став классикой современной детской литературы США.\n	{Романы}
698	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Волшебный дневник	\N	Сеси́лия Ахе́рн (англ. Cecelia Ahern, ирл. Cecelia Ní hEachthairn; род. 30 сентября 1981 года, Дублин, Ирландия) — писательница, автор любовных романов.\n	{Романы}
699	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Люблю твои воспоминания	\N	Сеси́лия Ахе́рн (англ. Cecelia Ahern, ирл. Cecelia Ní hEachthairn; род. 30 сентября 1981 года, Дублин, Ирландия) — писательница, автор любовных романов.\n	{Романы}
565	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Темное путешествие	\N	По мнению критиков (Вячеслав Бутусов, Иван Охлобыстин, Николай Дроздов и др.) «Год Весны» нельзя отнести к определенному жанру — это не роман и не автобиография, не путевые заметки и не пособие по страноведению[1]. В этой истории странствии уставшего от жизни опытного финансиста и топ-менеджера[2] есть место как описанию экзотических пейзажей и диалогов с туземцами, так и воспоминаниям о любви и душевным переживаниям, размышлениям и отрывкам из любимых книг.\n	{Фантастика}
566	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Принеси мне голову Прекрасного принца	\N	Трилогия создана в соавторстве двумя корифеями мировой фантастики — Робертом Шекли и Роджером Желязны. В неё также входят следующие романы:\n	{Фантастика}
567	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Если с Фаустом вам не повезло	\N	В русском переводе книга также известна под названием «Коль с Фаустом тебе не повезло». Весьма вольное и оригинальное прочтение германского эпоса и произведения Гёте о докторе Фаусте, приправленное свойственным Шекли и Желязны юмором, ёрничанием, остроумием и вопросами о смысле жизни и месте человека в этом мире.\n	{Фантастика}
568	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пьеса должна продолжаться	\N	Первая публикация в 1995 году. В 1997 году произведение выходит в России в серии «Библиотека приключений и фантастики».\n	{Фантастика}
569	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Свет Угрюмого	\N	\N	{Фантастика}
570	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Умереть в Италбаре	\N	\N	{Фантастика}
700	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Там, где заканчивается радуга	\N	Сеси́лия Ахе́рн (англ. Cecelia Ahern, ирл. Cecelia Ní hEachthairn; род. 30 сентября 1981 года, Дублин, Ирландия) — писательница, автор любовных романов.\n	{Романы}
572	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Владения Хаоса	\N	\N	{Фантастика}
573	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Рука Оберона	\N	Первая публикация глав романа состоялась в журнале Galaxy Science Fiction.\n	{Фантастика}
845	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Третья девушка	\N	\N	{Детектив}
575	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Знак Хаоса	\N	Была номинирована в 1988 году на премию Locus Award.[1]\n	{Фантастика}
576	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Рыцарь Теней	\N	На русский язык в разное время роман переводили: Ян Юа, Е. Доброхотова-Майкова, Е. Волковыский.\n	{Фантастика}
702	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Милый друг	\N	«Ми́лый друг» (фр. Bel-Ami) — роман французского писателя Ги де Мопассана, написанный в 1885 году. Рассказывает об авантюристе, который мечтает сделать блестящую карьеру. У него нет каких-либо талантов, разве что своей внешностью он может покорить сердце любой дамы, а совесть прощает ему любую подлость. И… этого хватает для того, чтобы стать сильным мира сего.\n	{Романы}
578	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кровь Амбера	\N	На русский язык книгу переводили в разное время: Ян Юа, Н. Белякова, М. Гутов. Варианты переводов названия: «Кровь Эмбера», «Кровь Янтаря».\n	{Фантастика}
579	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Знак единорога	\N	«Знак Единорога» — роман американского писателя-фантаста Роджера Желязны, вышедший в 1975 году. Третья книга из первой пенталогии цикла романов «Хроники Амбера». Предыдущая книга — «Ружья Авалона». Следующая книга цикла — «Рука Оберона».\n	{Фантастика}
580	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Карты судьбы	\N	\N	{Фантастика}
581	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Девять принцев Амбера	\N	\N	{Фантастика}
705	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Монт-Ориоль	\N	Как отмечал французский исследователь творчества Мопассана Андре Виаль, писатель точно описал курортную жизнь в Шатель-Гюйоне и реально происходившую борьбу двух лечебных предприятий. По мнению Виаля, прототипом старого крестьянина Ориоля был житель Шатель-Гюйона, крестьянин Пре-Лижье.[1][2]\n	{Романы}
710	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Джен Эйр	\N	«Джейн Эйр» (англ. Jane Eyre [ˌdʒeɪn ˈɛər]), в самой первой публикации был выпущен под названием «Джейн Эйр: Автобиография» (англ. Jane Eyre: An Autobiography) — роман английской писательницы Шарлотты Бронте, выпущенный под псевдонимом «Каррер Белл». Второе переиздание романа Бронте посвятила писателю Уильяму Теккерею.\n	{Романы}
711	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Тэсс из рода Д`Эрбервиллей	\N	Эпиграфом к этому произведению служат слова У. Шекспира: «…Бедное поруганное имя! Сердце моё, как ложе приютит тебя».\n	{Романы}
586	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Замок ведьм	\N	\N	{Фантастика}
712	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Секреты обольщения	\N	Роберт Грин (англ. Robert Greene, р. 14 мая 1959 года в Лос-Анджелесе) — американский автор популярно-публицистической литературы о психологии и механизме функционирования власти в обществе и политике, а также об особенностях стратегического мышления и законах обольщения.\n	{Романы}
713	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Укрощение герцога	\N	Родоначальник — Вильгельм I, сын Вильгельма Фридриха Вюртембергского, состоявшего в морганатическом браке с  фрейлиной его матери — Вильгельминой фон Тундерфельд-Родис (1777—1822), 28 марта 1867 года получил титул герцога фон Урах от вюртембергского короля Карла I.\n	{Романы}
589	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Песни Петера Сьлядека	\N	В сборнике повествуется о путешествиях барда Петера Сьлядека, родом из Хенинга, что соответствует северной Германии или Голландии — на этом основании «Песни» объединяются (в том числе издателями) с «Богадельней» в «Хенингский Цикл». Действие рассказов происходит в различных странах, соответствующих Восточной Европе, по мере странствий главного героя — параллель Польши, параллель Словакии, параллель Сербии, параллель Украине времен Тараса Бульбы. Действие книги происходит в Средневековье, однако временные рамки очень размыты. Главный герой Петер Сьлядек присутствует в каждом рассказе; отдельные персонажи также мельком упоминаются в нескольких частях, например, Белинда ван Дайк («Здесь и сейчас», «Баллада двойников»).\n	{Фантастика}
590	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ничей дом	\N	\N	{Фантастика}
591	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мастер	\N	\N	{Фантастика}
715	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Много шума из-за невесты	\N	«Мно́го шу́ма из ничего́» (англ. Much Ado About Nothing) — пьеса английского писателя Уильяма Шекспира, одна из наиболее известных комедий автора.\n	{Романы}
593	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Смех Диониса	\N	Книга представляет собой первую часть трилогии о Тиме Талере, куда входят также повести «Куклы Тима Талера, или Проданное человеколюбие» (1977) и «Неле, или Вундеркинд» (1986).\n	{Фантастика}
594	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Последний	\N	\N	{Фантастика}
595	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Скидка на талант	\N	Скидка — добровольное, одностороннее снижение стоимости товара (услуги) продавцом (поставщиком услуги) от первоначальной стоимости товара (услуги). Также термином «скидка» обозначают размер скидки, то есть сумму, на которую снижается продажная цена товара, реализуемого покупателю.\n	{Фантастика}
716	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Неприличные занятия	\N	Изначально написана для работы на карманном компьютере Sharp Zaurus, а позже была портирована на несколько платформ, в число которых входят Siemens SIMpad, Archos PMA430, Motorola (E680i, A780, A1200, E8/Em30, Zn5, u9), Nokia Internet Tablet, Familiar, Windows XP и Linux на ПК и электронных книгах. В версии для ОС Linux для создания пользовательского интерфейса используются библиотеки Qt4.\n	{Романы}
717	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Супруг для леди	\N	Алекса́ндра Мари́нина (настоящее имя — Мари́на Анато́льевна Алексе́ева; род. 16 июня 1957, Львов[3]) — российский писатель-прозаик, автор большого количества произведений детективного жанра.\n	{Романы}
598	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Монстр	\N	The focus is on monsters and fantastical and legendary creatures from religion, mythology, folklore, fairy tales, literary fantasy, science fiction, cryptids and other anomalous phenomena. Monster in My Pocket produced trading cards, comic books, books, toys, a board game, a video game, and an animated special, along with music, clothing, kites, stickers, and various other items.\n	{Фантастика}
719	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мэнсфильд-парк	\N	«Мэ́нсфилд-парк» (англ. Mansfield Park) — воспитательный роман Джейн Остин (1811—13), который принадлежит к зрелому периоду её творчества. Увидел свет в 1814 году.\n	{Романы}
600	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Тигр	\N	John Vaillant is an American writer and journalist whose work has appeared in The New Yorker, The Atlantic, National Geographic, and Outside. He has written both non-fiction and fiction books.\n	{Фантастика}
720	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гордость и предубеждение	\N	«Го́рдость и предубеждéние» (англ. Pride and Prejudice) — роман Джейн Остин, который увидел свет в 1813 году.\n	{Романы}
835	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Случайный гость	\N	Фильм снимался в городе Тарраса, а также в других местах в Испании — Барселоне и регионе Бискайя[3].\n	{Детектив}
721	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Нортенгерское аббатство	\N	«Нортенгерское абба́тство» — первый подготовленный к публикации роман Джейн Остин, хотя он был написан после «Чувства и чувствительности» и «Гордости и предубеждения».\n	{Романы}
722	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Доводы рассудка	\N	\N	{Романы}
605	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Герой должен быть один	\N	Роман «Одиссей, сын Лаэрта» нельзя считать продолжением этого романа в полном смысле этого слова, хотя связь их несомненна.\n	{Фантастика}
723	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Разум и чувства	\N	«Чувство и чувствительность» (англ. Sense and Sensibility) — роман английской писательницы Джейн Остин. Первое изданное произведение писательницы было опубликовано в 1811 году под псевдонимом некая Леди.\n	{Романы}
607	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Nevermore	\N	\N	{Фантастика}
725	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Поющие в терновнике	\N	«Пою́щие в терно́внике» (англ. The Thorn Birds, дословно «птицы терновника») — семейная сага австралийской писательницы Колин Маккалоу, опубликованная в 1977 году.\n	{Романы}
729	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Раздели со мной жизнь	\N	Ким (Кимол) Алекса́ндрович Бре́йтбург (род. 10 февраля 1955, Львов, Украинская ССР, СССР) — советский и российско-украинский музыкальный продюсер, аранжировщик и композитор, звукорежиссёр, вокалист. Заслуженный деятель искусств Российской Федерации (2006). Автор мюзиклов, музыки для кино и телевидения, композитор. По состоянию на 2017 год написал более 600 песен[1].\n	{Романы}
610	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Докладная записка	\N	\N	{Фантастика}
611	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Последнее допущение господа	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Фантастика}
733	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Моя любимая ошибка	\N	Нора Робертс (англ. Nora Roberts, при рождении  — Элеонора Мари Робертсон Ауфем-Бринк Уайлдер англ. Eleanor Marie Robertson Aufem-Brinke Wilder; род. 10 октября 1950, Силвер-Спринг, Мэриленд) — американская писательница, автор современных любовных[en] и детективных романов.\n	{Романы}
613	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Рассказы	\N	\N	{Фантастика}
734	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вероника решает умереть	\N	Книга входит в серию «И в день седьмой…» вместе с другими двумя произведениями автора («На берегу Рио-Пьедра села я и заплакала», «Дьявол и сеньорита Прим»).[1]\n	{Романы}
615	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Магелланово Облако - royallib.ru	\N	\N	{Фантастика}
616	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Машина времени	\N	\N	{Фантастика}
617	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Книга 2	\N	\N	{Приключения}
618	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Книга 1	\N	\N	{Приключения}
619	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Шантарам	\N	Shantaram is a 2003 novel by Gregory David Roberts, in which a convicted Australian bank robber and heroin addict escapes from Pentridge Prison and flees to India. The novel is commended by many for its vivid portrayal of tumultuous life in Bombay.\n	{Приключения}
620	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сага о Форсайтах	\N	\N	{Приключения}
738	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Роман в лесу	\N	«В леса́х» — 1200-страничный роман Павла Мельникова-Печерского. Публиковался Михаилом Катковым в журнале «Русский вестник» в 1871—1874 годах. Вместе с романом 1881 года «На горах» образует дилогию[1], своеобразную энциклопедию старообрядческой жизни[2]. Обычно публикуется в двух книгах.\n	{Романы}
739	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Удольфские тайны	\N	Анна Радклиф (англ. Ann Radcliffe, урождённая Уорд (англ. Ward); 9 июля 1764 — 7 февраля 1823) — английская писательница, одна из основательниц готического романа.\n	{Романы}
741	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Первые впечатления	\N	\N	{Романы}
742	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Птичка певчая	\N	\N	{Романы}
746	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	На одном дыхании	\N	\N	{Детектив}
747	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Хроника гнусных времен	\N	\N	{Детектив}
651	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Стоящий у Солнца	\N	\N	{Приключения}
755	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Колодец забытых желаний	\N	\N	{Детектив}
749	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Персональный ангел	\N	\N	{Детектив}
750	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Всегда говори  - всегда	\N	\N	{Детектив}
751	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Подруга особого назначения	\N	\N	{Детектив}
838	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Десять негритят	\N	\N	{Детектив}
839	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Смерть Мисс Мак-Джинти	\N	\N	{Детектив}
752	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гений пустого места	\N	Сэр Э́лтон Геркулес Джон[1] (англ. Elton Hercules John, урожд. Ре́джинальд Ке́ннет Дуа́йт (англ. Reginald Kenneth Dwight); род. 25 марта 1947[2], Пиннер, Мидлсекс, Англия, Великобритания) — британский певец, пианист и композитор, радиоведущий. Оказал заметное влияние на развитие лёгкого рока[3]. Один из самых коммерчески успешных исполнителей 1970-х годов и один из самых успешных рок-исполнителей Великобритании. За всю свою карьеру он продал в США и Великобритании больше альбомов, чем любой другой британский соло-исполнитель[4].\n	{Детектив}
760	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Миф об идеальном мужчине	\N	Дми́трий Ива́нович Менделе́ев (27 января [8 февраля] 1834, Тобольск — 20 января [2 февраля] 1907, Санкт-Петербург) — русский учёный-энциклопедист: химик, физикохимик, физик, метролог, экономист, технолог, геолог, метеоролог, нефтяник, педагог, воздухоплаватель, приборостроитель. Профессор Императорского Санкт-Петербургского университета; член-корреспондент (по разряду «физический») Императорской Санкт-Петербургской Академии наук. Среди самых известных открытий — периодический закон химических элементов, один из фундаментальных законов мироздания, неотъемлемый для всего естествознания. Автор классического труда «Основы химии»[9]. Тайный советник.\n	{Детектив}
761	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пять шагов по облакам	\N	Дми́трий Ива́нович Менделе́ев (27 января [8 февраля] 1834, Тобольск — 20 января [2 февраля] 1907, Санкт-Петербург) — русский учёный-энциклопедист: химик, физикохимик, физик, метролог, экономист, технолог, геолог, метеоролог, нефтяник, педагог, воздухоплаватель, приборостроитель. Профессор Императорского Санкт-Петербургского университета; член-корреспондент (по разряду «физический») Императорской Санкт-Петербургской Академии наук. Среди самых известных открытий — периодический закон химических элементов, один из фундаментальных законов мироздания, неотъемлемый для всего естествознания. Автор классического труда «Основы химии»[9]. Тайный советник.\n	{Детектив}
765	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мой личный враг	\N	\N	{Детектив}
766	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Отель последней надежды	\N	«Отель» (Hotel) — роман-бестселлер 1965 года канадского писателя Артура Хейли. Производственный роман, как и все романы Хейли. Всё действие романа происходит в течение пяти дней — с понедельника по пятницу; главы произведения названы по дням недели.\n	{Детектив}
772	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Весь мир - театр	\N	Акунин задумал серию «Приключения Эраста Фандорина» как краткое изложение всех жанров детектива, каждый роман представлял собой новый жанр[1]. В данном романе действие разворачивается в театре и вокруг театра, отсюда и название.\n	{Детектив}
632	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Клуб самоубийц	\N	\N	{Приключения}
773	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Особые приключения. Пиковый валет	\N	Акунин задумал серию "Приключения Эраста Фандорина" как краткое изложение всех жанров детектива, каждый роман представлял собой новый жанр. [1]\n	{Детектив}
774	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Любовник смерти	\N	Действия книги происходят параллельно действиям в «Любовнице смерти».\n	{Детектив}
635	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Баллады	\N	Балла́да (пров. balada, от ballar плясать[1][2]) — многозначный литературный и музыкальный термин. Основные значения:\n	{Приключения}
776	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Алмазная колесница	\N	Акунин задумал серию «Приключения Эраста Фандорина» как краткое изложение всех жанров детектива, каждый роман представлял собой новый жанр[1]. В данной книге описываются этнические особенности японцев.\n	{Детектив}
637	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Девятный Спас	\N	\N	{Приключения}
811	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вино из мандрагоры	\N	\N	{Детектив}
680	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Путешествия Гулливера	\N	\N	{Приключения}
681	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Похитители бриллиантов	\N	\N	{Приключения}
840	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	После похорон	\N	\N	{Детектив}
778	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Любовница смерти	\N	Акунин задумал серию «Приключения Эраста Фандорина» как краткое изложение всех жанров детектива, каждый роман представлял собой новый жанр. В данном детективе речь идёт о странном желании людей покончить с собой.\n	{Детектив}
779	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Статский советник	\N	«Статский советник» — исторический роман Бориса Акунина из серии «Приключения Эраста Фандорина».\n	{Детектив}
780	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Особые приключения. Декоратор	\N	Декоратор (повесть о маньяке) — книга Бориса Акунина из серии «Приключения Эраста Фандорина». Вместе с повестью «Пиковый валет» образуют книгу «Особые поручения».\n	{Детектив}
640	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Граф Монте-Кристо	\N	„Граф Монте Кристо“ е приключенски роман от Александър Дюма. Често се смята, че трябва да се нарежда заедно с Тримата мускетари ( Les Trois Mousquetaires), най-популярната творба на Дюма. Той завършва творбата през 1844 г. Както много от новелите му, тя е разширение на сюжета, предложен от сътрудничеството му с Огюст Маке.\n	{Приключения}
781	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Нефритовые четки	\N	Сборник рассказов и небольших повестей раскрывает читателю, где был и что делал Эраст Петрович в промежутках между делами, описанными в предыдущих книгах серии, а также отвечает на вопросы: откуда взялись нефритовые чётки, с которыми герой никогда не расставался? Почему на знаменитом портрете Фандорин изображён в мундире студента Института инженеров путей сообщения (где никогда не учился)? Как он познакомился с Ангелиной Крашенинниковой? Почему его назвали Эрастом?\n	{Детектив}
782	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Турецкий гамбит	\N	«Турецкий гамбит» (шпионский детектив) — книга Бориса Акунина из серии «Приключения Эраста Фандорина».\n	{Детектив}
783	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Смерть Ахиллеса	\N	Акунин задумал серию «Приключения Эраста Фандорина» как краткое изложение всех жанров детектива, каждый роман представлял собой новый жанр[1]. Как видно из названия данного жанра, в этой книге преступник — наёмный убийца.\n	{Детектив}
784	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Коронация, или Последний из романов	\N	Борис Акунин задумал серию книг «Приключения Эраста Фандорина» как краткое изложение всех жанров детектива, каждый роман представлял собой новый жанр детектива.[2] Данная книга описывает события в высшем обществе Российской Империи — царской семье.\n	{Детектив}
645	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кольцо принцессы	\N	\N	{Приключения}
785	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Азазель	\N	«Азазель» (конспирологический детектив) — книга Бориса Акунина, первый роман из серии о необыкновенном сыщике Эрасте Петровиче Фандорине «Приключения Эраста Фандорина». В английском переводе книга называется «Зимняя королева» (Winter Queen)[1], что соответствует названию гостиницы в Лондоне, которая фигурирует в повествовании.\n	{Детектив}
814	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Черная роза	\N	\N	{Детектив}
648	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Земля сияющей власти	\N	\N	{Приключения}
794	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Улыбка пересмешника	\N	«Уби́ть пересме́шника» (англ. To Kill a Mockingbird) — роман-бестселлер[1][2] американской писательницы Харпер Ли, опубликованный в 1960 году. В 1961 году получил Пулитцеровскую премию. Его успех стал вехой в борьбе за права чернокожих.\n	{Детектив}
682	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Прекрасная Маргарет	\N	\N	{Приключения}
756	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Закон обратного волшебства	\N	\N	{Детектив}
796	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Призрак в кривом зеркале	\N	\N	{Детектив}
798	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Танцы марионеток	\N	Рэй Ду́глас Брэ́дбери (англ. Ray Douglas Bradbury; 22 августа 1920 года, Уокиган, США — 5 июня 2012 года, Лос-Анджелес[6][8][9]) — американский писатель, известный по антиутопии «451 градус по Фаренгейту», циклу рассказов «Марсианские хроники» и частично автобиографической повести «Вино из одуванчиков»[10][11].\n	{Детектив}
799	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Жизнь под чужим солнцем	\N	Черновым названием сценария было «Полмиллиона золотом, вплавь, пешком и волоком». Источником вдохновения для режиссёра послужили картины Серджо Леоне с Клинтом Иствудом в главной роли[2].\n	{Детектив}
800	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мужская логика 8 марта	\N	\N	{Детектив}
801	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Убийственная библиотека	\N	В 1960 году на деньги семьи Бейнеке началось строительство здания библиотеки по проекту архитектора Гордона Буншафта из фирмы Skidmore, Owings and Merrill.\n	{Детектив}
802	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Время собирать камни	\N	«Время собирать камни» — российский художественный фильм 2005 года.\n	{Детектив}
803	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Черная кошка в белой комнате	\N	\N	{Детектив}
807	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Колье от Лалик	\N	Рене́ Лали́к (фр. René Jules Lalique; 6 апреля 1860, Аи, Марна — 1 мая 1945, Париж) — французский ювелир и стеклянных дел мастер, один из выдающихся представителей ар нуво.\n	{Детектив}
809	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Месопотамский демон	\N	\N	{Детектив}
815	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Зеленый омут	\N	Станислав Пятрасович Пье́ха (до 7 лет Герулис[1]) (род. 13 августа 1980[2], Ленинград, СССР) — российский певец. Участник проекта «Фабрика звёзд». Владелец клиники комплексного лечения алкоголизма, наркомании и реабилитации[3].\n	{Детектив}
817	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Золотые нити	\N	Фильм рассказывает о возможных последствиях ядерной войны. В картине использованы достаточно простые спецэффекты, которые, однако, позволяют довольно реалистично показать глобальную катастрофу. Авторы сравнивают современную цивилизацию с нитями паутины, которая очень сложна, однако может быть легко уничтожена.\n	{Детектив}
657	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	К последнему морю	\N	\N	{Приключения}
818	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кольцо Гекаты	\N	Гека́та (др.-греч. Ἑκάτη) — древнегреческая богиня лунного света, преисподней, всего таинственного, магии и колдовства[2]. Внучка титанов.[3]\n	{Детектив}
659	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Батый	\N	\N	{Приключения}
823	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Шарада Шекспира	\N	\N	{Детектив}
824	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Печать фараона	\N	«Фараон» (польск. Faraon) — исторический роман известного польского писателя Болеслава Пруса (1847—1912), написанный в 1895 г. и изначально публиковавшийся в варшавском «Иллюстрированном еженедельнике». Первое издание в книжном варианте появилось в 1897 году.\n	{Детектив}
825	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Венера Челлини	\N	\N	{Детектив}
829	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Звезда Вавилона	\N	Вавило́н (логографика: KÁ.DINGIR.RAKI, аккад. Bābili или Babilim «врата бога»; др.-греч. Βαβυλών) — древний город в Южной Месопотамии, столица Вавилонского царства. Важный политический, экономический и культурный центр Древнего мира, один из крупнейших городов в истории человечества и «первый мегаполис»[5]; известный символ христианской эсхатологии и современной культуры. Руины Вавилона — группа холмов у города Эль-Хилла (Ирак), в 90 километрах к югу от Багдада; объект всемирного наследия ЮНЕСКО[6].\n	{Детектив}
832	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Загадки последнего сфинкса	\N	\N	{Детектив}
858	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Разбитое зеркало	\N	\N	{Детектив}
846	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Убийство в Месопотамии	\N	Основан на личных впечатлениях А. Кристи от археологических раскопок в Ираке под руководством Леонарда Вулли, в которых она принимала участие в 1929 и 1930 гг. Роман отличается ярким психологизмом.\n	{Детектив}
847	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Смерть лорда Эджвера	\N	«Смерть лорда Эджвера» (англ. Lord Edgware Dies) — детективный роман Агаты Кристи с участием Эркюля Пуаро и его приятелей капитана Гастингса и инспектора Скотленд-Ярда Джеппа. Впервые опубликован в сентябре 1933 году британским издательством Collins Crime Club. Роман лёг в основу нескольких кинофильмов и телесериалов. В РФ выпускался также под названиями «Смерть лорда Эдвера» и «Тринадцать сотрапезников».\n	{Детектив}
850	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пуаро ведет следствие	\N	Суперобложка первого издания с изображением Пуаро в утреннем костюме с тростью была продана в 2019 году за более чем 40 000 фунтов, и стала самой дорогой вещью, имеющей отношение к Кристи[1].\n	{Детектив}
851	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Хикори, дикори, док...	\N	\N	{Детектив}
852	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ранние дела Пуаро	\N	\N	{Детектив}
853	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Убийство в Каретном ряду	\N	Убийство в проходном дворе (англ. Murder in the Mews) — сборник из четырёх рассказов Агаты Кристи, посвящённых расследованиям Эркюля Пуаро. Впервые опубликован отдельным изданием 15 марта 1937 год издательством Collins Crime Club.\n	{Детектив}
854	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Лощина	\N	«Лощи́на» (англ. The Hollow) — детективный роман Агаты Кристи, впервые опубликованный издательством Collins Crime Club в Великобритании и издательством Dodd, Mead and Company в США в 1946 году. Роман из серии произведений Агаты Кристи об Эркюле Пуаро.[1] На русском языке издавался также под названием «Смерть в бассейне» («Смерть у бассейна»).\n	{Детектив}
856	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пять поросят	\N	\N	{Детектив}
663	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Яд и корона	\N	«Про́клятые короли́» (фр. Les Rois maudits) — серия из семи исторических романов французского писателя Мориса Дрюона, посвященных истории Франции первой половины XIV века, начиная с 1314 года, когда был окончен процесс над тамплиерами, и заканчивая событиями после битвы при Пуатье.\n	{Приключения}
664	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Железный король	\N	«Про́клятые короли́» (фр. Les Rois maudits) — серия из семи исторических романов французского писателя Мориса Дрюона, посвященных истории Франции первой половины XIV века, начиная с 1314 года, когда был окончен процесс над тамплиерами, и заканчивая событиями после битвы при Пуатье.\n	{Приключения}
665	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Узница Шато-Гайара	\N	\N	{Приключения}
666	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Негоже лилиям прясть	\N	«Про́клятые короли́» (фр. Les Rois maudits) — серия из семи исторических романов французского писателя Мориса Дрюона, посвященных истории Франции первой половины XIV века, начиная с 1314 года, когда был окончен процесс над тамплиерами, и заканчивая событиями после битвы при Пуатье.\n	{Приключения}
667	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Лилия и лев	\N	От 1961 г. развива непрекъсната изпълнителска и концертна дейност, записва песни и албуми, има медийни изяви, участва в телевизионни програми, снима се във видеоклипове. В знак на уважение за приноса си към българската популярна музика понякога е наричана „Примата на българската естрада“.\n	{Приключения}
857	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Убийство в проходном дворе	\N	Убийство в проходном дворе (англ. Murder in the Mews) — сборник из четырёх рассказов Агаты Кристи, посвящённых расследованиям Эркюля Пуаро. Впервые опубликован отдельным изданием 15 марта 1937 год издательством Collins Crime Club.\n	{Детектив}
669	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Когда король губит Францию	\N	«Про́клятые короли́» (фр. Les Rois maudits) — серия из семи исторических романов французского писателя Мориса Дрюона, посвященных истории Франции первой половины XIV века, начиная с 1314 года, когда был окончен процесс над тамплиерами, и заканчивая событиями после битвы при Пуатье.\n	{Приключения}
670	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пустой Трон	\N	\N	{Приключения}
671	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Языческий лорд	\N	После ухода римлян с островов в пятом веке, Британия оказалась раздробленной на множество мелких королевств. Вторжение викингов на Британские острова вызвало волну кровопролития, затяжных войн и разорения.\n	{Приключения}
672	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Смерть королей	\N	\N	{Приключения}
860	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Тайна Голубого поезда	\N	\N	{Детектив}
861	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вечеринка в Хэллоуин	\N	Отличительной чертой романа стало нечастое сотрудничество Эркюля Пуаро и писательницы Ариадны Оливер\n	{Детектив}
862	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Слоны умеют помнить	\N	Это последний роман о Пуаро по времени написания Агатой Кристи. Роман «Занавес», в котором Пуаро умирает, был написан в начале Второй Мировой войны. [1]\n	{Детектив}
676	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Горящая земля	\N	\N	{Приключения}
677	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Властелин Севера	\N	\N	{Приключения}
678	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Трое на четырех колесах	\N	\N	{Приключения}
863	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Конец человеческой глупости	\N	\N	{Детектив}
875	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Свидание со смертью	\N	Роман повествует о приключениях Эркюля Пуаро на Ближнем Востоке.\n	{Детектив}
864	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Загадка Эндхауза	\N	«Загадка Эндхауза» (англ. Peril at End House, в другом переводе — «Преступление на вилле "Энд"»[1]) — детективный роман английской писательницы Агаты Кристи 1932 года. Является седьмой книгой с участием частного сыщика Эркюля Пуаро.\n	{Детектив}
865	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Убийство на поле для гольфа	\N	\N	{Детектив}
866	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Убийство в Восточном экспрессе	\N	«Убийство в „Восточном экспрессе“» (англ. Murder on the Orient Express) — детективный роман английской писательницы Агаты Кристи, написанный в 1933 году в Ираке, где она находилась в археологической экспедиции со своим вторым мужем Максом Маллованом. Является одним из наиболее известных произведений романистки, ярким образцом романов её так называемого «восточного цикла».\n	{Детектив}
867	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Таинственное происшествие в Стайлз	\N	Это первая книга про бельгийского детектива Эркюля Пуаро, капитана Артура Гастингса и инспектора Джеппа — персонажей, которые будут фигурировать в десятках произведений писательницы. Роман написан от лица капитана Гастингса и содержит все элементы классического детектива («закрытая комната», много скрывающих что-либо подозреваемых в одном здании, схемы и планы, неожиданные повороты расследования, хитроумное использование яда). Об истории создания романа писательница подробно рассказала в своей «Автобиографии», что является уникальным случаем для её мемуаров.\n	{Детектив}
869	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кошка среди голубей	\N	«Кошка среди голубей» (англ. Cat Among the Pigeons) — поздний роман Агаты Кристи, который равно можно отнести как к детективному, так и к шпионскому жанру. Один из немногочисленных образцов шпионского детектива в творчестве писательницы. Роман стал последним произведением, где Эркюль Пуаро изображён ещё не отошедшим от дел детективом. Впервые опубликован 2 ноября 1959 года.\n	{Детектив}
870	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Карты на стол	\N	В другом переводе «Карты на столе»[1].\n	{Детектив}
871	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Убийство Роджера Экройда	\N	В книге детективное расследование убийства богатого фабриканта Роджера Экройда ведёт сыщик Пуаро. Ему помогает доктор Шеппард, от лица которого и ведётся повествование. В конце романа неожиданно выясняется, что убийцей является именно доктор, оказавшийся таким образом так называемым ненадёжным рассказчиком. В соответствии с традициями классического детектива читателю предоставлена возможность вычислить убийцу, однако в данном случае сделать это довольно сложно, поскольку читатель традиционно проникается доверием к рассказчику. Одной из важнейших проблем в творчестве Кристи является тема морали и возмездия преступнику за совершённое преступление. Эта тема трактуется в её произведениях различным образом, но главный принцип сводится к тому, что человек, совершивший жестокое преступление, не должен оставаться на свободе. Тем не менее Пуаро, определив убийцу, не передаёт его в руки правосудия, а предоставляет ему возможность покончить с собой.\n	{Детектив}
872	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Трагедия в трех актах	\N	В США роман выходил под названием «Murder in Three Acts» («Убийство в трёх актах»), а в России также переводился под заголовком «Драма в трёх актах».\n	{Детектив}
891	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вояж с морским дьяволом	\N	\N	{Детектив}
873	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Большая четверка	\N	«Большая четвёрка» (англ. The Big Four) — детективный и шпионский роман Агаты Кристи, опубликованный в 1927 году издательством William Collins & Sons. Роман рассказывает о расследовании Эркюля Пуаро, капитана Гастингса и инспектора Джеппа.\n	{Детектив}
691	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Праздник для двоих	\N	A Moveable Feast is a 1964 memoir by American author Ernest Hemingway about his years as a struggling expat journalist and writer in Paris during the 1920s. It was published posthumously.[1]The book details Hemingway's first marriage to Hadley Richardson and his associations with other cultural figures of the Lost Generation in Interwar France.\n	{Романы}
692	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Случайности не случайны	\N	\N	{Романы}
693	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Я люблю тебя	\N	\N	{Романы}
874	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Зло под солнцем	\N	«Зло под солнцем» (англ. Evil Under the Sun) — классический детективный роман Агаты Кристи из серии произведений о бельгийском сыщике Эркюле Пуаро. Впервые опубликован в июне 1941 года издательством Collins Crime Club в Великобритании.\n	{Детектив}
876	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Раз, два - пряжку застегни	\N	Другие переводы названия — «Раз, два, три, туфлю застегни», «Раз, два — пряжку застегни». В США выходил под названием «Патриотические убийства», в СССР — «Раз, раз — гость сидит у нас»[1].\n	{Детектив}
877	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Смерть на Ниле	\N	«Смерть на Ниле» (англ. Death on the Nile) — один из самых известных и значительных романов Агаты Кристи, ключевое произведение её «восточного цикла» с участием Эркюля Пуаро и полковника Рейса. Впервые опубликован в Великобритании 1 ноября 1937 года. В РФ сокращённый перевод был опубликован под названием «Убийство на пароходе „Карнак“».\n	{Детектив}
878	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Рождество Эркюля Пуаро	\N	«Рождество Эркюля Пуаро» (англ. Hercule Poirot's Christmas) — классический детективный роман Агаты Кристи с участием Эркюля Пуаро. Впервые опубликован 19 декабря 1938 года.\n	{Детектив}
880	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Смерть в облаках	\N	\N	{Детектив}
882	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Лунный камень	\N	«Лунный камень», англ. The Moonstone (1866) — роман английского писателя Уилки Коллинза. По определению критика Т. С. Элиота — самый первый, самый длинный и лучший детективный роман в английской литературе. Вместе с романом «Женщина в белом» считается лучшим произведением Коллинза, а также одним из лучших детективных романов всех времен.\n	{Детектив}
883	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Испанская легенда	\N	«Альгамбра» (англ. Tales of the Alhambra) — книга американского писателя периода романтизма Вашингтона Ирвинга, сборник новелл, эссе и путевых заметок, посвященный знаменитому мавританскому дворцу в Гранаде — Альгамбре и его истории. Из этой книги (глава «Легенда об арабском звездочёте / астрологе») Пушкин позаимствовал фабулу «Сказки о золотом петушке».\n	{Детектив}
886	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Я-ваши неприятности	\N	Татья́на Поляко́ва (настоящее имя — Татья́на Ви́кторовна Рога́нова; род. 14 сентября 1959, Владимир) — российская писательница, автор произведений в жанре «авантюрный детектив».\n	{Детектив}
887	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Человек, подаривший ей собаку	\N	Татья́на Поляко́ва (настоящее имя — Татья́на Ви́кторовна Рога́нова; род. 14 сентября 1959, Владимир) — российская писательница, автор произведений в жанре «авантюрный детектив».\n	{Детектив}
701	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Подарок	\N	\N	{Романы}
888	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Даже ведьмы умеют плакать	\N	\N	{Детектив}
703	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Жизнь	\N	In Christianity and Judaism, the Book of Life (Hebrew: ספר החיים, transliterated Sefer HaChaim; Greek: βιβλίον τῆς ζωῆς Biblíon tēs Zōēs) is the  book in which God records the names of every person who is destined for Heaven or the World to Come.[citation needed]  According to the Talmud it is open on Rosh Hashanah, as is its analog for the wicked, the Book of the Dead. For this reason extra mention is made for the Book of Life during Amidah recitations during the Days of Awe, the ten days between Rosh Hashanah, the Jewish new year, and Yom Kippur, the day of atonement (the two High Holidays, particularly in the prayer Unetaneh Tokef).\n	{Романы}
704	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	На воде	\N	\N	{Романы}
889	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Солнце светит не всем	\N	\N	{Детектив}
706	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пьер и Жан	\N	Pierre Bourdieu (French: [buʁdjø]; 1 August 1930 – 23 January 2002) was a French sociologist, anthropologist, philosopher and public intellectual.[4][5] Bourdieu's contributions to the sociology of education, the theory of sociology, and sociology of aesthetics have achieved wide influence in several related academic fields (e.g. anthropology, media and cultural studies, education, popular culture, and the arts). During his academic career he was primarily associated with the School for Advanced Studies in the Social Sciences in Paris and the Collège de France.\n	{Романы}
707	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Доктор Ираклий Глосс	\N	\N	{Романы}
708	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пышка	\N	\N	{Романы}
709	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Анжелюс	\N	\N	{Романы}
892	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Парфюмер звонит первым	\N	«Парфюмер. История одного убийцы» (нем. Das Parfum. Die Geschichte eines Mörders) — роман немецкого драматурга и прозаика Патрика Зюскинда.\n	{Детектив}
893	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Второй раз не воскреснешь	\N	\N	{Детектив}
894	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пальмы, солнце, алый снег	\N	\N	{Детектив}
732	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Что я без тебя	\N	\N	{Романы}
757	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Жизнь, по слухам, одна	\N	\N	{Детектив}
758	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мой генерал	\N	\N	{Детектив}
759	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Близкие люди	\N	\N	{Детектив}
895	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Красивые, дерзкие, злые	\N	\N	{Детектив}
897	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Осколки великой мечты	\N	\N	{Детектив}
714	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Вкус блаженства	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Романы}
718	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пропавшее кольцо	\N	\N	{Романы}
724	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Эмма	\N	\N	{Романы}
726	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Наследиe	\N	\N	{Романы}
727	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Незаконнорожденная	\N	\N	{Романы}
728	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гимн Рождества	\N	\N	{Романы}
730	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Лук Амура	\N	\N	{Романы}
731	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Битва желаний	\N	Джудит Макнот (англ. Judith McNaught; родилась 10 мая 1944) — американская писательница, автор 17 любовных романов. Именно Макнот является основоположником жанра исторического любовного романа эпохи Регентства[1].\n	{Романы}
735	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Властелин воды	\N	\N	{Романы}
736	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мемуары гейши	\N	«Мемуары гейши» — роман американского автора Артура Голдена, опубликованный в 1997 году. В романе от первого лица рассказывается вымышленная история о гейше, работающей в Киото, Япония, до и после Второй мировой войны. Роман знакомит читателя с многими японскими традициями и с культурой гейш.\n	{Романы}
737	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Итальянец	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Романы}
740	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Рыцарь	\N	\N	{Романы}
743	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Заповедник чувств	\N	\N	{Романы}
744	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Богиня прайм-тайма	\N	В своей трилогии Керстин Гир рассказывает о путешествиях во времени, любви и верности, предательстве и коварстве, лжи и искуплении. Главная героиня цикла, Гвендолин Шеферд — обычный шестнадцатилетний подросток, неожиданно для себя узнаёт, что ей достался ген путешественника во времени. Так начинаются её приключения, по ходу которых девушке придётся разгадать тайну двенадцати, обрести новых друзей и познать муки первой любви.\n	{Детектив}
745	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дом-фантом в приданое	\N	\N	{Детектив}
748	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Запасной инстинкт	\N	\N	{Детектив}
753	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Саквояж со светлым будущим	\N	\N	{Детектив}
754	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Одна тень на двоих	\N	\N	{Детектив}
762	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Большон зло и мелкие пакости	\N	\N	{Детектив}
763	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Олигарх с Большой Медведицы	\N	\N	{Детектив}
764	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Там, где нас нет	\N	\N	{Детектив}
767	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пороки и их поклонники	\N	\N	{Детектив}
768	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	От первого до последнего слова	\N	\N	{Детектив}
769	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Седьмое небо	\N	\N	{Детектив}
770	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Первое правило королевы	\N	\N	{Детектив}
771	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Развод и девичья фамилия	\N	\N	{Детектив}
775	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Левиафан	\N	\N	{Детектив}
777	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Черный город	\N	По заявлению автора — последняя книга из цикла об Эрасте Фандорине. Выход романа состоялся 8 февраля 2018 года[1].\n	{Детектив}
786	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дом одиноких сердец	\N	\N	{Детектив}
787	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Манускрипт дьявола	\N	\N	{Детектив}
788	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Рыцарь нашего времени	\N	Тринадцать коротких глав романа рассказывают о ранних годах жизни Леона, чувствительного и нежного мальчика. По признанию самого Карамзина, роман «основан на воспоминаниях молодости, которыми автор занимался во время душевной и телесной болезни».\n	{Детектив}
789	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Золушка и дракон	\N	\N	{Детектив}
790	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Комната старинных ключей	\N	\N	{Детектив}
812	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кольцо с коралловой эмалью	\N	\N	{Детектив}
813	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Танец индийской богини	\N	\N	{Детектив}
859	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Часы	\N	Часы́ — прибор для определения текущего времени суток и измерения продолжительности временных интервалов в единицах, меньших, чем одни сутки. Самыми точными часами считаются атомные часы.\n	{Детектив}
792	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Знак истинного пути	\N	ZIP — формат архивации файлов и сжатия данных без потерь. Архив ZIP может содержать один или несколько файлов и каталогов, которые могут быть сжаты разными алгоритмами. Наиболее часто в ZIP используется алгоритм сжатия Deflate. Формат был создан в 1989 году Филом Кацем и реализован в программе PKZIP компании PKWARE[2] в качестве замены формату архивов ARC Тома Хендерсона. Формат ZIP поддерживается множеством программ, в том числе операционными системами Microsoft Windows (с 1998 года) и Apple Mac OS X (с версии 10.3). Многие свободные операционные системы также имеют встроенную поддержку ZIP-архивов.\n	{Детектив}
793	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Темная сторона души	\N	\N	{Детектив}
795	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Водоворот чужих желаний	\N	\N	{Детектив}
797	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Остров сбывшейся мечты	\N	\N	{Детектив}
804	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сокровище Китеж-града	\N	Ки́теж (Ки́теж-град, град Ки́теж, Большо́й Ки́теж) — мессианистический город, находившийся, по легенде, в северной части Нижегородской области, около села Владимирского, на берегах озера Светлояр у реки Люнда.\n	{Детектив}
805	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кинжал Зигфрида	\N	\N	{Детектив}
806	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Золотой Идол Огнебога	\N	\N	{Детектив}
808	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Гороскоп	\N	Гороскоп — упорядоченное отображение взаимного расположения планет на звёздном небе в определенный промежуток времени по знакам зодиака. Используется в астрологии с целью предсказания судьбы.\n	{Детектив}
810	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Медальон	\N	Медальон (через нем. medaillon или фр. médaillon, от итал. medaglione, увеличительное от medaglia — медаль[1][2]) — украшение или памятный знак круглой или овальной формы.\n	{Детектив}
816	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Иллюзии красного	\N	\N	{Детектив}
819	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пятерка мечей	\N	\N	{Детектив}
820	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Третье рождение Феникса	\N	\N	{Детектив}
821	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Испанские шахматы	\N	\N	{Детектив}
822	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Московский лабиринт Минотавра	\N	\N	{Детектив}
826	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Этрусское зеркало	\N	Этруски были расселены преимущественно в районе к югу от долины реки По вплоть до Рима, ближе к западному побережью Апеннинского полуострова. Их история прослеживается примерно с 1000 г. до н. э. вплоть до I в. н. э., когда этруски были окончательно ассимилированы римлянами. Когда и откуда этруски попали в Италию, неясно, и их язык большинством учёных признаётся неиндоевропейским. Этруски испытали огромное влияние древнегреческой культуры, что сказалось и на религии. Так, множество сюжетов на этрусских зеркалах имеют несомненно греческое происхождение; это доказывают имена многих персонажей, записанные этрусским алфавитом на этрусском языке, но имеющие несомненно греческое происхождение. Многие верования этрусков стали частью культуры Древнего Рима; считалось, что этруски являются хранителями знаний о многих ритуалах, которые были недостаточно известны римлянам.\n	{Детектив}
827	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Черная жемчужина императора	\N	\N	{Детектив}
828	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Яд древней богини	\N	\N	{Детектив}
830	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Часы королевского астролога	\N	\N	{Детектив}
831	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Магия венецианского стекла	\N	\N	{Детектив}
833	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Золото скифов	\N	\N	{Детектив}
834	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ларец Лунной Девы	\N	\N	{Детектив}
836	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Монета желаний	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Детектив}
837	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	The Body in the Library	\N	\N	{Детектив}
842	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Невероятная кража	\N	\N	{Детектив}
843	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Приключения рождественского пудинга	\N	В состав сборника входят предисловие автора, в котором А. Кристи предается воспоминаниям о рождественских праздниках своего детства, и шесть рассказов.\n	{Детектив}
844	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Родосский треугольник	\N	\N	{Детектив}
855	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Подвиги Геракла	\N	\N	{Детектив}
868	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Занавес	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Детектив}
881	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Желтый пес - royallib.ru	\N	\N	{Детектив}
884	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Как бы не так	\N	Стандарт был разработан группой разработчиков во главе с Дмитрием Грибовым и Михаилом Мацневым.\n	{Детектив}
885	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Честное имя	\N	\N	{Детектив}
890	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Золотая дева	\N	\N	{Детектив}
1	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Народ, или Когда-то мы были дельфинами	\N	\N	{Фэнтези}
2	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Очень веская причина поверить в Санта-Клауса	\N	\N	{Фэнтези}
896	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	В Питер вернутся не все	\N	\N	{Детектив}
900	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Через время, через океан	\N	\N	{Детектив}
907	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Кот в мешке	\N	«Кот в мешке» —  что-либо, что покупается без знания о качествах, полезности и т.п. приобретаемого.\n	{Детектив}
908	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	По ту сторону барьера	\N	Советские политические обозреватели и журналисты-международники анализировали права и свободы человека в буржуазном обществе, разоблачали неприглядные стороны капиталистического мира, освещали деятельность спецслужб США и других капиталистических стран[1].\n	{Детектив}
17	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Правда	\N	\N	{Фэнтези}
40	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ведьмы за границей	\N	\N	{Фэнтези}
71	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Волонтеры вечности	\N	\N	{Фэнтези}
116	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Каждый хочет любить	\N	\N	{Фэнтези}
283	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Полет гарпии	\N	\N	{Фэнтези}
197	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Мемнох-дьявол	\N	\N	{Фэнтези}
201	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Переход	\N	\N	{Фэнтези}
262	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Полые холмы	\N	\N	{Фэнтези}
275	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Братство кольца	\N	\N	{Фэнтези}
295	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Хранитель драконов	\N	\N	{Фэнтези}
374	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Илиада	\N	\N	{Мифы,легенды}
609	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Пророк	\N	\N	{Фантастика}
630	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Сын Зевса	\N	\N	{Приключения}
636	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Остров сокровищ	\N	\N	{Приключения}
656	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Янки из Коннектикута при дворе короля Артура	\N	\N	{Приключения}
791	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Дудочка крысолова	\N	\N	{Детектив}
848	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Печальный кипарис	\N	\N	{Детектив}
849	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Убийство по алфавиту	\N	\N	{Детектив}
879	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Безмолвный свидетель	\N	\N	{Детектив}
898	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Эксклюзивный грех	\N	\N	{Детектив}
899	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Внебрачная дочь продюсера	\N	\N	{Детектив}
901	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Отпуск на тот свет	\N	\N	{Детектив}
902	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Коллекция страхов прет-а-порте	\N	\N	{Детектив}
903	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Я тебя никогда не забуду	\N	\N	{Детектив}
904	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Ревность волхвов	\N	\N	{Детектив}
905	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Рецепт идеальной мечты	\N	\N	{Детектив}
906	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	У судьбы другое имя	\N	\N	{Детектив}
909	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Убийственное меню	\N	Иоа́нна Хмеле́вская (польск. Joanna Chmielewska), настоящее имя писательницы — Ирена Барбара Кун (Irena Barbara Kuhn), урождённая Ирена Барбара Иоанна Беккер[1] (Irena Barbara Joanna Becker; 2 апреля 1932, Варшава — 7 октября 2013, Варшава[2]) — польская писательница, автор иронических детективов и основоположник этого жанра для русских читателей.\n	{Детектив}
910	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Колодцы предков	\N	Иоа́нна Хмеле́вская (польск. Joanna Chmielewska), настоящее имя писательницы — Ирена Барбара Кун (Irena Barbara Kuhn), урождённая Ирена Барбара Иоанна Беккер[1] (Irena Barbara Joanna Becker; 2 апреля 1932, Варшава — 7 октября 2013, Варшава[2]) — польская писательница, автор иронических детективов и основоположник этого жанра для русских читателей.\n	{Детектив}
911	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	Закон постоянного невезения	\N	Иоа́нна Хмеле́вская (польск. Joanna Chmielewska), настоящее имя писательницы — Ирена Барбара Кун (Irena Barbara Kuhn), урождённая Ирена Барбара Иоанна Беккер[1] (Irena Barbara Joanna Becker; 2 апреля 1932, Варшава — 7 октября 2013, Варшава[2]) — польская писательница, автор иронических детективов и основоположник этого жанра для русских читателей.\n	{Детектив}
\.


--
-- Data for Name: books_authors; Type: TABLE DATA; Schema: public; Owner: kurush
--

COPY public.books_authors (author_id, book_id) FROM stdin;
1	1
1	2
1	3
1	4
1	5
1	6
1	7
1	8
1	9
1	10
1	11
1	12
1	13
1	14
1	15
1	16
1	17
1	18
1	19
1	20
1	21
1	22
1	23
1	24
1	25
1	26
1	27
1	28
1	29
1	30
1	31
1	32
1	33
1	34
1	35
1	36
1	37
1	38
1	39
1	40
1	41
1	42
1	43
1	44
1	45
1	46
1	47
1	48
1	49
1	50
1	51
1	52
1	53
1	54
1	55
1	56
1	57
1	58
1	59
1	60
1	61
2	62
2	63
2	64
2	65
2	66
2	67
2	68
2	69
2	70
2	71
2	72
2	73
2	74
2	75
2	76
2	77
2	78
2	79
2	80
2	81
2	82
2	83
2	84
2	85
2	86
2	87
2	88
2	89
2	90
2	91
2	92
2	93
2	94
2	95
2	96
2	97
2	98
3	99
3	100
3	101
3	102
4	103
4	104
4	105
4	106
4	107
4	108
4	109
4	110
4	111
5	112
5	113
5	114
5	115
5	116
5	117
5	118
6	119
6	120
6	121
6	122
6	123
6	124
6	125
6	126
6	127
6	128
6	129
6	130
6	131
7	132
7	133
7	134
7	135
7	136
7	137
7	138
7	139
7	140
7	141
8	142
8	143
8	144
8	145
8	146
8	147
8	148
8	149
8	150
8	151
9	152
9	153
9	154
9	155
9	156
10	157
10	158
10	159
10	160
10	161
10	162
10	163
11	164
12	165
12	166
12	167
12	168
12	169
12	170
12	171
12	172
12	173
12	174
12	175
12	176
12	177
12	178
12	179
12	180
12	181
12	182
13	183
14	184
14	185
14	186
14	187
14	188
14	189
14	190
14	191
14	192
14	193
14	194
14	195
14	196
14	197
14	198
15	199
15	200
15	201
15	202
16	203
16	204
16	205
16	206
16	207
16	208
16	209
16	210
16	211
16	212
17	213
17	214
18	215
18	216
18	217
18	218
18	219
18	220
18	221
18	222
18	223
18	224
18	225
18	226
18	227
19	228
19	229
19	230
19	231
19	232
19	233
19	234
20	235
20	236
21	237
22	238
23	239
23	240
23	241
23	242
23	243
23	244
23	245
23	246
23	247
23	248
23	249
23	250
23	251
23	252
23	253
24	254
24	255
24	256
24	257
24	258
24	259
24	260
25	261
25	262
25	263
25	264
25	265
26	266
26	267
26	268
27	269
27	270
27	271
27	272
27	273
27	274
28	275
28	276
28	277
28	278
29	279
29	280
29	281
29	282
29	283
29	284
29	285
29	286
29	287
29	288
29	289
29	290
29	291
29	292
29	293
29	294
29	295
29	296
29	297
30	298
30	299
30	300
30	301
30	302
30	303
30	304
30	305
30	306
31	307
32	308
32	309
32	310
32	311
32	312
32	313
32	314
33	315
33	316
33	317
34	318
35	319
36	320
36	321
36	322
37	323
38	324
38	325
39	326
40	327
40	328
41	329
41	330
41	331
42	332
42	333
42	334
42	335
42	336
43	337
44	338
44	339
44	340
45	341
45	342
45	343
45	344
45	345
45	346
45	347
46	348
46	349
46	350
46	351
46	352
46	353
46	354
46	355
46	356
46	357
46	358
46	359
46	360
46	361
46	362
46	363
46	364
46	365
46	366
46	367
46	368
46	369
46	370
46	371
46	372
46	373
47	374
97	375
47	376
97	377
48	378
49	379
50	380
51	381
52	382
52	383
52	384
52	385
52	386
52	387
52	388
52	389
52	390
52	391
52	392
52	393
52	394
52	395
52	396
52	397
52	398
52	399
52	400
53	401
53	402
53	403
53	404
53	405
53	406
53	407
54	408
54	409
54	410
54	411
54	412
54	413
54	414
54	415
54	416
54	417
54	418
54	419
54	420
54	421
54	422
54	423
54	424
54	425
54	426
54	427
54	428
54	429
54	430
54	431
54	432
54	433
54	434
54	435
54	436
54	437
54	438
54	439
54	440
54	441
54	442
54	443
54	444
54	445
54	446
54	447
54	448
54	449
54	450
54	451
54	452
54	453
54	454
54	455
54	456
54	457
54	458
54	459
54	460
54	461
54	462
54	463
54	464
54	465
54	466
54	467
54	468
54	469
54	470
54	471
54	472
54	473
54	474
54	475
54	476
54	477
54	478
54	479
54	480
54	481
54	482
54	483
54	484
54	485
54	486
54	487
54	488
54	489
54	490
54	491
54	492
54	493
54	494
54	495
54	496
54	497
54	498
54	499
54	500
54	501
54	502
54	503
54	504
54	505
54	506
54	507
54	508
54	509
54	510
54	511
54	512
54	513
54	514
54	515
54	516
55	517
55	518
55	519
55	520
55	521
55	522
55	523
55	524
55	525
55	526
55	527
56	528
56	529
56	530
56	531
56	532
56	533
57	534
57	535
57	536
58	537
58	538
59	539
59	540
59	541
59	542
59	543
59	544
59	545
59	546
59	547
59	548
59	549
59	550
59	551
59	552
59	553
60	554
60	555
60	556
61	557
61	558
61	559
61	560
61	561
61	562
61	563
61	564
61	565
61	566
61	567
61	568
61	569
61	570
61	571
61	572
61	573
61	574
61	575
61	576
61	577
61	578
61	579
61	580
61	581
62	582
63	583
63	584
63	585
63	586
63	587
64	588
64	589
64	590
64	591
64	592
64	593
64	594
64	595
64	596
64	597
64	598
64	599
64	600
64	601
64	602
64	603
64	604
64	605
64	606
64	607
64	608
64	609
64	610
64	611
64	612
64	613
64	614
65	615
66	616
70	617
70	618
71	619
72	620
72	621
74	622
75	623
75	624
76	625
77	626
78	627
79	628
79	629
80	630
80	631
81	632
81	633
81	634
81	635
81	636
82	637
83	638
83	639
83	640
84	641
84	642
84	643
85	644
86	645
86	646
86	647
86	648
86	649
86	650
86	651
86	652
86	653
87	654
87	655
87	656
88	657
88	658
88	659
88	660
89	661
89	662
90	663
90	664
90	665
90	666
90	667
90	668
90	669
91	670
91	671
91	672
91	673
91	674
91	675
91	676
91	677
92	678
92	679
93	680
94	681
95	682
95	683
95	684
96	685
96	686
96	687
96	688
98	689
99	690
100	691
101	692
102	693
102	694
102	695
102	696
102	697
102	698
102	699
102	700
102	701
103	702
103	703
103	704
103	705
103	706
103	707
103	708
103	709
104	710
105	711
106	712
107	713
107	714
107	715
107	716
107	717
108	718
109	719
109	720
109	721
109	722
109	723
109	724
110	725
111	726
111	727
112	728
131	729
113	730
114	731
114	732
115	733
18	734
116	735
117	736
118	737
118	738
118	739
119	740
119	741
120	742
132	743
121	744
121	745
121	746
121	747
121	748
121	749
121	750
121	751
121	752
121	753
121	754
121	755
121	756
121	757
121	758
121	759
121	760
121	761
121	762
121	763
121	764
121	765
121	766
121	767
121	768
121	769
121	770
121	771
122	772
122	773
122	774
122	775
122	776
122	777
122	778
122	779
122	780
122	781
122	782
122	783
122	784
122	785
123	786
123	787
123	788
123	789
123	790
123	791
123	792
123	793
123	794
123	795
123	796
123	797
123	798
123	799
123	800
123	801
123	802
123	803
124	804
124	805
124	806
124	807
124	808
124	809
124	810
124	811
124	812
124	813
124	814
124	815
124	816
124	817
124	818
124	819
124	820
124	821
124	822
124	823
124	824
124	825
124	826
124	827
124	828
124	829
124	830
124	831
124	832
124	833
124	834
124	835
124	836
125	837
125	838
125	839
125	840
125	841
125	842
125	843
125	844
125	845
125	846
125	847
125	848
125	849
125	850
125	851
125	852
125	853
125	854
125	855
125	856
125	857
125	858
125	859
125	860
125	861
125	862
125	863
125	864
125	865
125	866
125	867
125	868
125	869
125	870
125	871
125	872
125	873
125	874
125	875
125	876
125	877
125	878
125	879
125	880
126	881
127	882
128	883
128	884
128	885
128	886
128	887
129	888
129	889
129	890
129	891
129	892
129	893
129	894
129	895
129	896
129	897
129	898
129	899
129	900
129	901
129	902
129	903
129	904
129	905
129	906
130	907
130	908
130	909
130	910
130	911
\.


--
-- Data for Name: books_series; Type: TABLE DATA; Schema: public; Owner: kurush
--

COPY public.books_series (series_id, book_id, book_number) FROM stdin;
1	1	4
1	2	5
1	3	7
1	4	6
1	5	2
1	6	3
1	7	1
2	8	2
2	9	4
2	10	6
2	11	7
2	12	1
2	13	3
2	14	5
2	15	1
2	16	6
2	17	4
2	18	5
2	19	3
2	20	2
2	21	5
2	22	4
2	23	8
2	24	6
2	25	1
2	26	3
2	27	7
2	28	2
2	29	11
2	30	10
2	31	9
2	32	6
2	33	5
2	34	8
2	35	10
2	36	1
2	37	9
2	38	7
2	39	11
2	40	3
2	41	4
2	42	2
2	43	6
2	44	2
2	45	8
2	46	7
2	47	5
2	48	1
2	49	4
2	50	3
2	51	1
2	52	3
2	53	2
3	54	3
3	55	2
3	56	1
5	57	3
5	58	2
5	59	1
6	60	1
6	61	2
7	62	4
7	63	6
7	64	3
7	65	5
7	66	1
7	67	7
7	68	2
8	70	1
8	71	2
8	72	5
8	73	8
8	74	7
8	75	9
8	76	10
8	77	6
8	78	3
8	79	4
9	82	3
9	83	5
9	84	8
9	85	6
9	86	4
9	87	1
9	88	7
9	89	2
10	91	4
10	92	1
10	93	5
10	94	7
10	95	6
10	96	2
10	97	3
10	98	8
11	99	3
11	100	4
11	101	2
11	102	1
12	103	4
12	104	3
12	105	5
12	106	2
12	107	1
12	108	6
13	109	1
13	110	3
13	111	2
14	119	13
14	120	6
14	121	10
14	122	2
14	123	4
14	124	3
14	125	8
14	126	5
14	127	7
14	128	12
14	129	1
14	130	11
14	131	9
15	133	3
15	134	2
15	135	1
16	142	2
16	143	1
16	144	4
16	145	5
16	146	3
17	165	6
17	166	14
17	167	13
17	168	2
17	169	3
17	170	15
17	171	8
17	172	12
17	173	11
17	174	5
17	175	7
17	176	1
17	177	4
17	178	10
17	179	9
18	180	2
18	181	3
18	182	1
19	184	4
19	185	6
19	186	2
19	187	5
19	188	3
19	189	1
20	190	8
20	191	2
20	192	1
20	193	6
20	194	4
20	195	9
20	196	3
20	197	5
20	198	7
21	199	4
21	200	3
21	201	1
21	202	2
22	203	2
22	204	1
23	205	4
23	206	3
23	207	1
23	208	2
23	209	5
24	210	1
24	211	2
24	212	3
25	225	1
25	226	3
25	227	2
26	228	2
26	229	1
26	230	6
26	231	3
26	232	5
26	233	4
26	234	7
27	235	1
27	236	2
28	239	15
28	240	9
28	241	6
28	242	4
28	243	2
28	244	3
28	245	1
28	246	14
28	247	7
28	248	12
28	249	5
28	250	10
28	251	11
28	252	8
28	253	13
29	254	3
29	255	2
29	256	5
29	257	4
29	258	6
29	259	1
29	260	7
30	261	3
30	262	2
30	263	1
30	264	4
30	265	5
31	266	3
31	267	2
31	268	1
32	279	1
32	280	4
32	281	3
32	282	2
33	283	1
33	284	2
34	285	1
34	286	2
34	287	3
35	288	1
35	289	3
35	290	2
36	291	3
36	292	2
36	293	1
37	294	2
37	295	1
37	296	4
37	297	3
38	298	1
38	299	3
38	300	2
39	302	2
39	303	4
39	304	5
39	305	3
39	306	1
40	308	5
40	309	4
40	310	1
40	311	2
40	312	3
40	313	7
40	314	6
41	426	1
41	427	2
42	429	8
42	430	3
42	431	5
42	432	4
42	433	2
42	434	6
42	435	9
42	436	7
42	437	1
43	461	1
44	462	1
45	470	2
45	471	1
46	488	1
46	489	3
46	490	5
46	491	2
46	492	4
47	517	2
47	518	8
47	519	9
47	520	10
47	521	7
47	522	4
47	523	3
47	524	6
47	525	1
47	526	5
47	527	11
48	528	4
48	529	3
48	530	6
48	531	2
48	532	1
48	533	5
49	559	2
49	560	1
49	561	3
50	563	2
50	564	1
51	566	1
51	567	2
51	568	3
52	569	3
52	570	2
52	571	1
53	572	5
53	573	4
53	574	2
53	575	8
53	576	9
53	577	10
53	578	7
53	579	3
53	580	6
53	581	1
54	588	1
54	589	2
55	590	4
55	591	7
55	592	5
55	593	9
55	594	10
55	595	8
55	596	1
55	597	11
55	598	2
55	599	6
55	600	3
55	601	12
56	602	2
56	603	3
56	604	1
57	606	2
57	607	6
57	608	5
57	609	7
57	610	4
57	611	3
57	612	1
58	617	2
58	618	1
59	630	1
59	631	2
60	632	1
60	633	2
61	647	4
61	648	3
61	649	5
61	650	6
61	651	1
61	652	2
62	657	3
62	658	1
62	659	2
63	663	3
63	664	1
63	665	2
63	666	4
63	667	6
63	668	5
63	669	7
64	670	8
64	671	7
64	672	6
64	673	2
64	674	1
64	675	4
64	676	5
64	677	3
65	713	4
65	714	5
65	715	1
65	716	3
65	717	2
66	772	13
66	773	5
66	774	9
66	775	3
66	776	10
66	777	14
66	778	8
66	779	15
66	780	6
66	781	12
66	782	2
66	783	4
66	784	7
66	785	1
67	787	10
67	788	5
67	789	11
67	790	12
67	791	9
67	792	1
67	793	3
67	794	8
67	795	4
67	796	6
67	797	2
67	798	7
68	804	1
68	805	3
68	806	2
69	807	3
69	808	2
69	809	6
69	810	5
69	811	1
69	812	4
69	813	7
70	814	4
70	815	3
70	816	2
70	817	1
71	818	2
71	819	1
72	820	1
72	821	8
72	822	4
72	823	3
72	824	5
72	825	9
72	826	7
72	827	6
72	828	2
73	829	6
73	830	3
73	831	1
73	832	2
73	833	5
73	834	4
74	839	24
74	840	25
74	841	22
74	842	10
74	843	29
74	844	13
74	845	31
74	846	5
74	847	41
74	848	17
74	849	4
74	850	23
74	851	26
74	852	35
74	853	37
74	854	20
74	855	21
74	856	19
74	857	9
74	858	11
74	859	30
74	860	39
74	861	32
74	862	33
74	863	27
74	864	40
74	865	12
74	866	2
74	867	1
74	868	36
74	869	28
74	870	6
74	871	34
74	872	42
74	873	38
74	874	18
74	875	14
74	876	16
74	877	7
74	878	15
74	879	8
74	880	3
\.


--
-- Data for Name: publications; Type: TABLE DATA; Schema: public; Owner: kurush
--

COPY public.publications (id, book_id, created_at, updated_at, publication_year, language_code, isbn, isbn13, info) FROM stdin;
1	1	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
2	2	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
3	3	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
4	4	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
5	5	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
6	6	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
7	7	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
8	8	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
9	9	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
10	10	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
11	11	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
12	12	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
13	13	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
14	14	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
15	15	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
16	16	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
17	17	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
18	18	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
19	19	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
20	20	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
21	21	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
22	22	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
23	23	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
24	24	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
25	25	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
26	26	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
27	27	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
28	28	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
29	29	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
30	30	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
31	31	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
32	32	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
33	33	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
34	34	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
35	35	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
36	36	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
37	37	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
38	38	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
39	39	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
40	40	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
41	41	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
42	42	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
43	43	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
44	44	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
45	45	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
46	46	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
47	47	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
48	48	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
49	49	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
50	50	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
51	51	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
52	52	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
53	53	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
54	54	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
55	55	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
56	56	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
57	57	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
58	58	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
59	59	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
60	60	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
61	61	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
62	62	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
63	63	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
64	64	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
65	65	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
66	66	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
67	67	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
68	68	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
69	69	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
70	70	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
71	71	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
72	72	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
73	73	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
74	74	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
75	75	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
76	76	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
77	77	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
78	78	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
79	79	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
80	80	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
81	81	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
82	82	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
83	83	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
84	84	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
85	85	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
86	86	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
87	87	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
88	88	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
89	89	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
90	90	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
91	91	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
92	92	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
93	93	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
94	94	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
95	95	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
96	96	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
97	97	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
98	98	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
99	99	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
100	100	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
101	101	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
102	102	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
103	103	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
104	104	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
105	105	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
106	106	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
107	107	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
108	108	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
109	109	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
110	110	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
111	111	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
112	112	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
113	113	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
114	114	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
115	115	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
116	116	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
117	117	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
118	118	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
119	119	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
120	120	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
121	121	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
122	122	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
123	123	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
124	124	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
125	125	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
126	126	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
127	127	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
128	128	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
129	129	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
130	130	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
131	131	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
132	132	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
133	133	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
134	134	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
135	135	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
136	136	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
137	137	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
138	138	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
139	139	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
140	140	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
141	141	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
142	142	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
143	143	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
144	144	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
145	145	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
146	146	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
147	147	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
148	148	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
149	149	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
150	150	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
151	151	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
152	152	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
153	153	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
154	154	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
155	155	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
156	156	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
157	157	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
158	158	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
159	159	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
160	160	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
161	161	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
162	162	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
163	163	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
164	164	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
165	165	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
166	166	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
167	167	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
168	168	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
169	169	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
170	170	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
171	171	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
172	172	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
173	173	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
174	174	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
175	175	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
176	176	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
177	177	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
178	178	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
179	179	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
180	180	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
181	181	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
182	182	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
183	183	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
184	184	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
185	185	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
186	186	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
187	187	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
188	188	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
189	189	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
190	190	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
191	191	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
192	192	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
193	193	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
194	194	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
195	195	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
196	196	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
197	197	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
198	198	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
199	199	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
200	200	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
201	201	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
202	202	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
203	203	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
204	204	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
205	205	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
206	206	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
207	207	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
208	208	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
209	209	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
210	210	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
211	211	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
212	212	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
213	213	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
214	214	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
215	215	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
216	216	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
217	217	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
218	218	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
219	219	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
220	220	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
221	221	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
222	222	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
223	223	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
224	224	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
225	225	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
226	226	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
227	227	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
228	228	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
229	229	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
230	230	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
231	231	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
232	232	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
233	233	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
234	234	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
235	235	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
236	236	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
237	237	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
238	238	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
239	239	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
240	240	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
241	241	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
242	242	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
243	243	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
244	244	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
245	245	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
246	246	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
247	247	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
248	248	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
249	249	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
250	250	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
251	251	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
252	252	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
253	253	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
254	254	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
255	255	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
256	256	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
257	257	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
258	258	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
259	259	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
260	260	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
261	261	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
262	262	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
263	263	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
264	264	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
265	265	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
266	266	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
267	267	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
268	268	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
269	269	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
270	270	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
271	271	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
272	272	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
273	273	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
274	274	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
275	275	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
276	276	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
277	277	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
278	278	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
279	279	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
280	280	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
281	281	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
282	282	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
283	283	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
284	284	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
285	285	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
286	286	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
287	287	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
288	288	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
289	289	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
290	290	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
291	291	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
292	292	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
293	293	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
294	294	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
295	295	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
296	296	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
297	297	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
298	298	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
299	299	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
300	300	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
302	302	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
303	303	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
304	304	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
305	305	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
306	306	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
307	307	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
308	308	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
309	309	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
310	310	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
311	311	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
312	312	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
313	313	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
314	314	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
315	315	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
316	316	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
317	317	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
318	318	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
319	319	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
320	320	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
321	321	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
322	322	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
323	323	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
324	324	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
325	325	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
326	326	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
327	327	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
328	328	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
329	329	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
330	330	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
331	331	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
332	332	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
333	333	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
334	334	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
335	335	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
336	336	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
337	337	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
338	338	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
339	339	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
340	340	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
341	341	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
342	342	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
343	343	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
344	344	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
345	345	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
346	346	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
347	347	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
348	348	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
349	349	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
350	350	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
351	351	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
352	352	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
353	353	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
354	354	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
355	355	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
356	356	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
357	357	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
358	358	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
359	359	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
360	360	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
361	361	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
362	362	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
363	363	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
364	364	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
365	365	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
366	366	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
367	367	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
368	368	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
369	369	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
370	370	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
371	371	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
372	372	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
373	373	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
374	374	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
375	375	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
376	376	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
377	377	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
378	378	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
379	379	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
380	380	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
381	381	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
382	382	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
383	383	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
384	384	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
385	385	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
386	386	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
387	387	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
388	388	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
389	389	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
390	390	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
391	391	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
392	392	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
393	393	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
394	394	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
395	395	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
396	396	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
397	397	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
398	398	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
399	399	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
400	400	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
401	401	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
402	402	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
403	403	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
404	404	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
405	405	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
406	406	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
407	407	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
408	408	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
409	409	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
410	410	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
411	411	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
412	412	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
413	413	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
414	414	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
415	415	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
416	416	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
417	417	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
418	418	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
419	419	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
420	420	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
421	421	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
422	422	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
423	423	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
424	424	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
425	425	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
426	426	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
427	427	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
428	428	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
429	429	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
430	430	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
431	431	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
432	432	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
433	433	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
434	434	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
435	435	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
436	436	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
437	437	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
438	438	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
439	439	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
440	440	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
441	441	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
442	442	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
443	443	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
444	444	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
445	445	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
446	446	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
447	447	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
448	448	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
449	449	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
450	450	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
451	451	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
452	452	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
453	453	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
454	454	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
455	455	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
456	456	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
457	457	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
458	458	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
459	459	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
460	460	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
461	461	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
462	462	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
463	463	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
464	464	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
465	465	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
466	466	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
467	467	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
468	468	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
469	469	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
470	470	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
471	471	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
472	472	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
473	473	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
474	474	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
475	475	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
476	476	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
477	477	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
478	478	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
479	479	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
480	480	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
481	481	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
482	482	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
483	483	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
484	484	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
485	485	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
486	486	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
487	487	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
488	488	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
489	489	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
490	490	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
491	491	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
492	492	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
493	493	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
494	494	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
495	495	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
496	496	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
497	497	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
498	498	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
499	499	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
500	500	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
501	501	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
502	502	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
503	503	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
504	504	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
505	505	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
506	506	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
507	507	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
508	508	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
509	509	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
510	510	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
511	511	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
512	512	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
513	513	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
514	514	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
515	515	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
516	516	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
517	517	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
518	518	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
519	519	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
520	520	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
521	521	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
522	522	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
523	523	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
524	524	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
525	525	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
526	526	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
527	527	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
528	528	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
529	529	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
530	530	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
531	531	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
532	532	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
533	533	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
534	534	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
535	535	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
536	536	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
537	537	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
538	538	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
539	539	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
540	540	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
541	541	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
542	542	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
543	543	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
544	544	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
545	545	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
546	546	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
547	547	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
548	548	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
549	549	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
550	550	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
551	551	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
552	552	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
553	553	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
554	554	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
555	555	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
556	556	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
557	557	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
558	558	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
559	559	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
560	560	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
561	561	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
562	562	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
563	563	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
564	564	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
565	565	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
566	566	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
567	567	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
568	568	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
569	569	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
570	570	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
571	571	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
572	572	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
573	573	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
574	574	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
575	575	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
576	576	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
577	577	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
578	578	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
579	579	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
580	580	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
581	581	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
582	582	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
583	583	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
584	584	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
585	585	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
586	586	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
587	587	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
588	588	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
589	589	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
590	590	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
591	591	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
592	592	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
593	593	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
594	594	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
595	595	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
596	596	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
597	597	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
598	598	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
599	599	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
600	600	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
601	601	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
602	602	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
603	603	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
604	604	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
605	605	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
606	606	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
607	607	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
608	608	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
609	609	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
610	610	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
611	611	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
612	612	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
613	613	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
614	614	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
615	615	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
616	616	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
617	617	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
618	618	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
619	619	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
620	620	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
621	621	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
622	622	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
623	623	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
624	624	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
625	625	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
626	626	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
627	627	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
628	628	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
629	629	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
630	630	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
631	631	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
632	632	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
633	633	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
634	634	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
635	635	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
636	636	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
637	637	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
638	638	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
639	639	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
640	640	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
641	641	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
642	642	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
643	643	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
644	644	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
645	645	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
646	646	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
647	647	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
648	648	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
649	649	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
650	650	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
651	651	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
652	652	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
653	653	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
654	654	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
655	655	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
656	656	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
657	657	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
658	658	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
659	659	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
660	660	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
661	661	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
662	662	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
663	663	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
664	664	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
665	665	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
666	666	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
667	667	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
668	668	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
669	669	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
670	670	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
671	671	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
672	672	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
673	673	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
674	674	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
675	675	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
676	676	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
677	677	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
678	678	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
679	679	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
680	680	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
681	681	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
682	682	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
683	683	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
684	684	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
685	685	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
686	686	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
687	687	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
688	688	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
689	689	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
690	690	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
691	691	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
692	692	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
693	693	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
694	694	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
695	695	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
696	696	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
697	697	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
698	698	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
699	699	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
700	700	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
701	701	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
702	702	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
703	703	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
704	704	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
705	705	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
706	706	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
707	707	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
708	708	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
709	709	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
710	710	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
711	711	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
712	712	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
713	713	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
714	714	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
715	715	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
716	716	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
717	717	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
718	718	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
719	719	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
720	720	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
721	721	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
722	722	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
723	723	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
724	724	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
725	725	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
726	726	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
727	727	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
728	728	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
729	729	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
730	730	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
731	731	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
732	732	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
733	733	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
734	734	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
735	735	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
736	736	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
737	737	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
738	738	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
739	739	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
740	740	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
741	741	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
742	742	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
743	743	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
744	744	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
745	745	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
746	746	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
747	747	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
748	748	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
749	749	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
750	750	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
751	751	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
752	752	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
753	753	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
754	754	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
755	755	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
756	756	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
757	757	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
758	758	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
759	759	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
760	760	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
761	761	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
762	762	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
763	763	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
764	764	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
765	765	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
766	766	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
767	767	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
768	768	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
769	769	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
770	770	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
771	771	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
772	772	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
773	773	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
774	774	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
775	775	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
776	776	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
777	777	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
778	778	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
779	779	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
780	780	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
781	781	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
782	782	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
783	783	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
784	784	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
785	785	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
786	786	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
787	787	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
788	788	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
789	789	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
790	790	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
791	791	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
792	792	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
793	793	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
794	794	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
795	795	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
796	796	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
797	797	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
798	798	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
799	799	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
800	800	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
801	801	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
802	802	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
803	803	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
804	804	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
805	805	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
806	806	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
807	807	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
808	808	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
809	809	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
810	810	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
811	811	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
812	812	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
813	813	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
814	814	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
815	815	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
816	816	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
817	817	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
818	818	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
819	819	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
820	820	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
821	821	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
822	822	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
823	823	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
824	824	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
825	825	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
826	826	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
827	827	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
828	828	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
829	829	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
830	830	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
831	831	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
832	832	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
833	833	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
834	834	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
835	835	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
836	836	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
837	837	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
838	838	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
839	839	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
840	840	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
841	841	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
842	842	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
843	843	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
844	844	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
845	845	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
846	846	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
847	847	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
848	848	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
849	849	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
850	850	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
851	851	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
852	852	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
853	853	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
854	854	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
855	855	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
856	856	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
857	857	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
858	858	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
859	859	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
860	860	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
861	861	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
862	862	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
863	863	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
864	864	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
865	865	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
866	866	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
867	867	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
868	868	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
869	869	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
870	870	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
871	871	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
872	872	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
873	873	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
874	874	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
875	875	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
876	876	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
877	877	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
878	878	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
879	879	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
880	880	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
881	881	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
882	882	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
883	883	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
884	884	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
885	885	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
886	886	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
887	887	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
888	888	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
889	889	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
890	890	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
891	891	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
892	892	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
893	893	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
894	894	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
895	895	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
896	896	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
897	897	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
898	898	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
899	899	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
900	900	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
901	901	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
902	902	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
903	903	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
904	904	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
905	905	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
906	906	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
907	907	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
908	908	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
909	909	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
910	910	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
911	911	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	ru	\N	\N	{}
912	301	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	\N	en	\N	\N	{}
301	301	2021-03-04 15:31:51.584645+00	2021-03-04 15:31:51.584645+00	2010	ru	\N	\N	{"переводчик": "Severus Smith", "опубликовано": "06.03.2019"}
\.


--
-- Data for Name: series; Type: TABLE DATA; Schema: public; Owner: kurush
--

COPY public.series (id, created_at, updated_at, title, is_finished, books_count, skin_image, description) FROM stdin;
55	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Бездна голодных глаз	\N	12	http://upload.wikimedia.org/wikipedia/commons/thumb/2/25/H._L._Oldie.jpg/250px-H._L._Oldie.jpg	\N
25	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	И в день седьмой	\N	3	http://upload.wikimedia.org/wikipedia/ru/8/88/%D0%92%D0%B5%D1%80%D0%BE%D0%BD%D0%B8%D0%BA%D0%B0_%D1%80%D0%B5%D1%88%D0%B0%D0%B5%D1%82_%D1%83%D0%BC%D0%B5%D1%80%D0%B5%D1%82%D1%8C.jpg	Книга входит в серию «И в день седьмой…» вместе с другими двумя произведениями автора («На берегу Рио-Пьедра села я и заплакала», «Дьявол и сеньорита Прим»).[1]\n
59	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Александр Македонский	\N	2	http://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Alexander_the_Great-Ny_Carlsberg_Glyptotek.jpg/280px-Alexander_the_Great-Ny_Carlsberg_Glyptotek.jpg	\N
67	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Макар Илюшин и Сергей Бабкин	\N	12	http://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/M1_Music_Awards_2019_%D0%A1%D0%B5%D1%80%D0%B3%D1%96%D0%B9_%D0%91%D0%B0%D0%B1%D0%BA%D1%96%D0%BD_%28cropped%29.jpg/274px-M1_Music_Awards_2019_%D0%A1%D0%B5%D1%80%D0%B3%D1%96%D0%B9_%D0%91%D0%B0%D0%B1%D0%BA%D1%96%D0%BD_%28cropped%29.jpg	Серге́й Никола́евич Ба́бкин (род. 7 ноября 1978, Харьков) — украинский музыкант, актёр, автор и исполнитель собственных песен. Участник группы «5’nizza». Тренер шоу «Голос страны» (2017, 2018). Участник 5-го сезона шоу «Танцы со звёздами» (вместе с супругой Снежаной Бабкиной).\n
68	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Артефакт	\N	3	http://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/OlgaTarasevich.jpg/215px-OlgaTarasevich.jpg	О́льга Ива́новна Тарасéвич (род. 19 февраля 1977, Минск, Белорусская ССР, СССР) — русская писательница. Одна из самых успешных писателей Беларуси[1][2].\n
60	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Приключения принца Флоризеля	\N	2	http://upload.wikimedia.org/wikipedia/ru/thumb/f/f0/Priklyucheniya-printsa-Florizelya.jpg/209px-Priklyucheniya-printsa-Florizelya.jpg	«Клуб самоуби́йц, или Приключе́ния титуло́ванной осо́бы» — приключенческий трёхсерийный телефильм по мотивам двух циклов повестей Р. Л. Стивенсона «Клуб самоубийц» и «Алмаз раджи». На телеэкраны вышел в январе 1981 года (хотя полностью готов был уже в 1979 году), под названием «Приключения принца Флоризеля». Оригинальное название и оригинальные титры, открывающие каждую серию фильма, были возвращены в 1990-х годах.\n
61	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Сокровища Валькирии	\N	6	http://upload.wikimedia.org/wikipedia/commons/thumb/4/4b/%D0%A1%D0%B5%D1%80%D0%B3%D0%B5%D0%B9_%D0%A2%D1%80%D0%BE%D1%84%D0%B8%D0%BC%D0%BE%D0%B2%D0%B8%D1%87_%D0%90%D0%BB%D0%B5%D0%BA%D1%81%D0%B5%D0%B5%D0%B2.jpg/274px-%D0%A1%D0%B5%D1%80%D0%B3%D0%B5%D0%B9_%D0%A2%D1%80%D0%BE%D1%84%D0%B8%D0%BC%D0%BE%D0%B2%D0%B8%D1%87_%D0%90%D0%BB%D0%B5%D0%BA%D1%81%D0%B5%D0%B5%D0%B2.jpg	Сергей Трофимович Алексеев (род. 20 января 1952 года) — российский писатель национал-патриотического направления. Творчество оказало влияние на развитие идей родноверия (славянского неоязычества)[2]. Член Союза писателей России[1].\n
66	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Приключения Эраста Фандорина	\N	14	http://upload.wikimedia.org/wikipedia/ru/thumb/3/36/%D0%AD%D1%80%D0%B0%D1%81%D1%82_%D0%A4%D0%B0%D0%BD%D0%B4%D0%BE%D1%80%D0%B8%D0%BD.jpg/274px-%D0%AD%D1%80%D0%B0%D1%81%D1%82_%D0%A4%D0%B0%D0%BD%D0%B4%D0%BE%D1%80%D0%B8%D0%BD.jpg	Персонаж Фандорина воплотил в себе идеал аристократа XIX века: благородство, образованность, преданность, неподкупность, верность принципам. Кроме того, Эраст Петрович хорош собой, у него безукоризненные манеры, он пользуется успехом у дам, хотя всегда одинок. Является также обладателем необычной способности — он всегда выигрывает в любой азартной игре и вообще в любом споре, если результат полностью определяется случайностью.\n
6	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Бесконечная Земля	\N	2	http://upload.wikimedia.org/wikipedia/ru/d/d9/The_Long_Earth.jpg	Идея о цепочке параллельных миров пришла Терри Пратчетту более 25 лет назад, но, в связи с работой над циклом «Плоский мир», замысел не был реализован[4].\n
37	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Хроники дождевых чащоб	\N	4	http://upload.wikimedia.org/wikipedia/ru/thumb/f/fd/%D0%A0%D0%BE%D0%B1%D0%B8%D0%BD_%D0%A5%D0%BE%D0%B1%D0%B1_%E2%80%94_Dragon_Keeper.jpg/240px-%D0%A0%D0%BE%D0%B1%D0%B8%D0%BD_%D0%A5%D0%BE%D0%B1%D0%B1_%E2%80%94_Dragon_Keeper.jpg	\N
5	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Джонни Максвелл	\N	3	\N	\N
12	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Песнь льда и огня	\N	6	http://upload.wikimedia.org/wikipedia/commons/8/86/Tr%C3%B4nedeFer1.png	«Песнь льда и огня» (англ. A Song of Ice and Fire, другой вариант перевода — «Песнь льда и пламени») — серия фэнтези-романов американского писателя и сценариста Джорджа Р. Р. Мартина. Мартин начал писать эту серию в 1991 году. Изначально задуманная как трилогия, к настоящему моменту она разрослась до пяти опубликованных томов, и ещё два находятся в проекте. Автором также написаны повести-приквелы и серия повестей, представляющих собой выдержки из основных романов серии. Одна из таких повестей, «Кровь дракона», была удостоена Премии Хьюго[1]. Три первых романа серии были награждены премией «Локус» за лучший роман фэнтези в 1997, 1999 и 2001 годах соответственно.\n
14	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	33 несчастья	\N	13	http://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/A_Series_of_Unfortunate_Events_logo.png/274px-A_Series_of_Unfortunate_Events_logo.png	«33 несчастья» — серия детских книг писателя Дэниела Хэндлера, пишущего под псевдонимом Лемони Сникет (англ. Lemony Snicket). Она повествует о трёх детях — Вайолет, Клаусе и Солнышке Бодлер — родители которых погибли в пожаре. Сироты переходят от одного опекуна к другому, но повсюду их преследуют разнообразные невзгоды и несчастья.\n
16	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Волкодав	\N	5	http://upload.wikimedia.org/wikipedia/ru/thumb/a/ac/%D0%9C%D0%B8%D1%80_%D0%92%D0%BE%D0%BB%D0%BA%D0%BE%D0%B4%D0%B0%D0%B2%D0%B0.jpg/274px-%D0%9C%D0%B8%D1%80_%D0%92%D0%BE%D0%BB%D0%BA%D0%BE%D0%B4%D0%B0%D0%B2%D0%B0.jpg	«Волкода́в» — серия романов российской писательницы Марии Семёновой. В серию входит 6 книг. Первая была издана в 1995 году, последняя — в 2014.\n
17	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Тайный город	\N	15	http://upload.wikimedia.org/wikipedia/ru/thumb/e/e8/%D0%9F%D0%B0%D0%BD%D0%BE%D0%B2_%D0%92%D0%BE%D0%B9%D0%BD%D1%8B_%D0%BD%D0%B0%D1%87%D0%B8%D0%BD%D0%B0%D1%8E%D1%82_%D0%BD%D0%B5%D1%83%D0%B4%D0%B0%D1%87%D0%BD%D0%B8%D0%BA%D0%B8.jpg/254px-%D0%9F%D0%B0%D0%BD%D0%BE%D0%B2_%D0%92%D0%BE%D0%B9%D0%BD%D1%8B_%D0%BD%D0%B0%D1%87%D0%B8%D0%BD%D0%B0%D1%8E%D1%82_%D0%BD%D0%B5%D1%83%D0%B4%D0%B0%D1%87%D0%BD%D0%B8%D0%BA%D0%B8.jpg	\N
18	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	La_Mystique_De_Moscou	\N	3	http://upload.wikimedia.org/wikipedia/commons/thumb/7/71/%D0%92%D0%B0%D0%B4%D0%B8%D0%BC_%D0%9F%D0%B0%D0%BD%D0%BE%D0%B2.jpg/274px-%D0%92%D0%B0%D0%B4%D0%B8%D0%BC_%D0%9F%D0%B0%D0%BD%D0%BE%D0%B2.jpg	Вади́м Ю́рьевич Пано́в (родился 15 ноября 1972) — российский писатель-фантаст. Автор цикла книг «Тайный город» (городское фэнтези), «Анклавы» (киберпанк), «La Mystique De Moscou» (городское фэнтези) и «Герметикон» (стимпанк).\n
19	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Мэйфейрские ведьмы	\N	6	http://upload.wikimedia.org/wikipedia/ru/thumb/b/bc/Lives_of_the_Mayfair_Witches_by_Anne_Rice.jpg/274px-Lives_of_the_Mayfair_Witches_by_Anne_Rice.jpg	Цикл создан в 1990—1994 годах, а в начале XXI века переведён на русский язык.\n
20	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Вампирские хроники	\N	9	http://upload.wikimedia.org/wikipedia/ru/thumb/5/5f/The_Vampire_Chronicles_by_Anne_Rice.jpg/274px-The_Vampire_Chronicles_by_Anne_Rice.jpg	Большая часть описания ведётся от первого лица и лишь немного от третьего. В 1994 г. был экранизирован первый том саги «Интервью с вампиром: Хроника жизни вампира», в главных ролях выступили Том Круз, Брэд Питт, Антонио Бандерас, Кристиан Слейтер, а также Кирстен Данст. Последующие два тома были объединены в кинофильм «Королева проклятых» 2002 г., где центральные роли исполнили Стюарт Таунсенд, Алия и Венсан Перес.\n
26	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Академия вампиров	\N	7	http://upload.wikimedia.org/wikipedia/ru/f/f3/Vampire_Academy.jpg	«Академия вампиров» (англ. Vampire Academy) — серия романтических книг о вампирах, созданная американской писательницей Райчел Мид. Первый роман был опубликован в 2007 году. В них описываются приключения семнадцатилетней девушки-дампира Розмари Хэзевей, которая обучается на специальность телохранителя для своей подруги, принцессы Лиссы, в вампирской школе — Академии св. Владимира.\n
27	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Нибелунги	\N	2	http://upload.wikimedia.org/wikipedia/commons/thumb/9/9b/Siegfried_awakens_Brunhild.jpg/274px-Siegfried_awakens_Brunhild.jpg	«Кольцо́ нибелу́нга» (нем. Der Ring des Nibelungen; Nibelung — «дитя тумана») — название цикла из четырёх эпических опер, основанных на реконструкциях германской мифологии, исландских сагах и средневековой поэме «Песнь о Нибелунгах»:\n
31	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Голодные игры	\N	3	http://upload.wikimedia.org/wikipedia/ru/thumb/6/60/HGTrilogy.jpg/273px-HGTrilogy.jpg	«Голодные игры» (англ. The Hunger Games) — трилогия американской писательницы Сьюзен Коллинз. В трилогию входят романы «Голодные игры» 2008 года, «И вспыхнет пламя» 2009 года и «Сойка-пересмешница» 2010 года. За короткое время книги трилогии стали бестселлерами[1], первые два романа почти два года[2] находились в списке самых продаваемых книг на территории США[3][4]. Компания Lionsgate выкупила права на экранизацию всех частей трилогии[5], мировая премьера фильма по первому роману состоялась 12 марта 2012 года[6], по второму роману — 11 ноября 2013 года[6][7], а выход оставшихся (фильм по роману «Сойка-пересмешница» разделён на две части) состоялся 10 ноября 2014 года[8] и 4 ноября 2015 года[9].\n
32	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Сага о живых кораблях	\N	4	http://upload.wikimedia.org/wikipedia/ru/a/a9/%D0%A0%D0%BE%D0%B1%D0%B8%D0%BD_%D0%A5%D0%BE%D0%B1%D0%B1_%E2%80%94_%D0%92%D0%BE%D0%BB%D1%88%D0%B5%D0%B1%D0%BD%D1%8B%D0%B9_%D0%BA%D0%BE%D1%80%D0%B0%D0%B1%D0%BB%D1%8C.jpg	\N
45	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Лунная бухта	\N	2	http://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Marissa_Meyer_%282018%29.jpg/274px-Marissa_Meyer_%282018%29.jpg	\N
34	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Сага о Шуте и убийце	\N	3	http://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Robin_Hobb_20060929_Fnac_01.jpg/266px-Robin_Hobb_20060929_Fnac_01.jpg	\N
36	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Сын солдата	\N	3	http://upload.wikimedia.org/wikipedia/ru/thumb/4/4b/%D0%A0%D0%BE%D0%B1%D0%B8%D0%BD_%D0%A5%D0%BE%D0%B1%D0%B1_%E2%80%94_%D0%9F%D1%83%D1%82%D1%8C_%D1%88%D0%B0%D0%BC%D0%B0%D0%BD%D0%B0.jpg/240px-%D0%A0%D0%BE%D0%B1%D0%B8%D0%BD_%D0%A5%D0%BE%D0%B1%D0%B1_%E2%80%94_%D0%9F%D1%83%D1%82%D1%8C_%D1%88%D0%B0%D0%BC%D0%B0%D0%BD%D0%B0.jpg	\N
2	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Плоский мир	\N	46	\N	«Плоский мир» (англ. Discworld — букв. «Мир-диск») — серия книг Терри Пратчетта, написанных в жанре юмористического фэнтези. Серия содержит более 40 книг и ориентирована преимущественно на взрослых, хотя четыре книги были выпущены на рынок как книги для детей или подростков[1]. Первые книги серии являются пародиями на общепринятое в жанре фэнтези, но в более поздних книгах писатель рассматривает проблемы реального мира[1]. \nБлагодаря «Плоскому миру» Пратчетт является одним из наиболее популярных авторов Великобритании.\n
3	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Книги номов	\N	3	\N	«Землекопы» и «Крылья» являются продолжением «Угонщиков». При этом события каждого сиквела развиваются параллельно, следуя за определёнными героями. Так, в «Угонщиках» и «Крыльях» центральным персонажем считается Масклин, а в «Землекопах» — Гримма.\n
1	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Вне циклов	\N	7	\N	Дорога домой — цикл романов российского писателя-фантаста Виталия Зыкова, повествующий о приключениях и странствиях группы людей, попавших в мир, отличный от нашего. Цикл завершён и насчитывает 6 книг, две последние состоят из двух томов. Вне основного цикла существуют авторские рассказы "Гамзарские байки", события которых происходят в той же вселенной, параллельно событиям основного цикла.\n
38	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Адские механизмы	\N	3	http://upload.wikimedia.org/wikipedia/commons/thumb/0/02/Cassandra_Clare_by_Gage_Skidmore%2C_2013_b.jpg/274px-Cassandra_Clare_by_Gage_Skidmore%2C_2013_b.jpg	Кассандра Клэр (англ. Cassandra Clare; настоящее имя — Джудит Румельт  (англ. Judith Rumelt); род. 31 июля 1973, Тегеран, Иран) — американская писательница. Наиболее известна как автор серии книг «Орудия смерти» и её приквела «Адские механизмы».\n
46	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Франкенштейн Дина Кунца	\N	5	\N	\N
41	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Джейн Хок	\N	2	http://upload.wikimedia.org/wikipedia/ru/thumb/0/09/The_Expanses_tv_logo.png/274px-The_Expanses_tv_logo.png	Действие сериала происходит через несколько сотен лет от нашего времени. Солнечная система постепенно колонизируется людьми («экспансия»), которые несут в космос с родной Земли свои многочисленные пороки — жадность, бесконтрольную рождаемость, преступность и коррупцию, взаимную ненависть, вооружённые конфликты и т. д. На этом фоне люди, сначала тайно, затем явно сталкиваются с молекулярным феноменом, который оказывается проявлением внеземной разумной жизни, давно освоившей множество звёздных систем и затем их таинственно покинувшей, оставив в полурабочем состоянии загадочную инфраструктуру.\n
42	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Странный Томас	\N	9	http://upload.wikimedia.org/wikipedia/ru/thumb/c/c2/%D0%9F%D0%BE%D1%81%D1%82%D0%B5%D1%80_%D1%84%D0%B8%D0%BB%D1%8C%D0%BC%D0%B0_%C2%AB%D0%A1%D1%82%D1%80%D0%B0%D0%BD%D0%BD%D1%8B%D0%B9_%D0%A2%D0%BE%D0%BC%D0%B0%D1%81%C2%BB.jpg/211px-%D0%9F%D0%BE%D1%81%D1%82%D0%B5%D1%80_%D1%84%D0%B8%D0%BB%D1%8C%D0%BC%D0%B0_%C2%AB%D0%A1%D1%82%D1%80%D0%B0%D0%BD%D0%BD%D1%8B%D0%B9_%D0%A2%D0%BE%D0%BC%D0%B0%D1%81%C2%BB.jpg	\N
22	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Страж	\N	2	http://upload.wikimedia.org/wikipedia/ru/6/64/%D0%A1%D1%82%D1%80%D0%B0%D0%B6%D0%B0%D0%A1%D1%82%D1%80%D0%B0%D0%B6%D0%B0.jpg	Восьмая книга из цикла «Плоский мир», первая книга подцикла о  Страже.\n
23	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Хроники Сиалы	\N	5	http://upload.wikimedia.org/wikipedia/ru/thumb/2/25/%D0%9A%D1%80%D0%B0%D0%B4%D1%83%D1%89%D0%B8%D0%B9%D1%81%D1%8F_%D0%B2_%D1%82%D0%B5%D0%BD%D0%B8.jpg/200px-%D0%9A%D1%80%D0%B0%D0%B4%D1%83%D1%89%D0%B8%D0%B9%D1%81%D1%8F_%D0%B2_%D1%82%D0%B5%D0%BD%D0%B8.jpg	\N
52	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Фрэнк Сандау	\N	3	http://upload.wikimedia.org/wikipedia/commons/thumb/a/ad/Arnold_B%C3%B6cklin_-_Die_Toteninsel_V_%28Museum_der_bildenden_K%C3%BCnste_Leipzig%29.jpg/275px-Arnold_B%C3%B6cklin_-_Die_Toteninsel_V_%28Museum_der_bildenden_K%C3%BCnste_Leipzig%29.jpg	«Остров мёртвых» (англ. Isle of the Dead) — роман американского писателя Роджера Желязны, вышедший в 1969.\nНоминирован в 1969 году на премию Небьюла за лучший роман[1], в 1972 году получил французскую премию Аполло[2].\n
54	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Хёнингский цикл	\N	2	http://upload.wikimedia.org/wikipedia/commons/thumb/2/25/H._L._Oldie.jpg/250px-H._L._Oldie.jpg	\N
28	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Колесо Времени	\N	15	wheel_of_time.png	\N
24	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Киндрэт	\N	3	\N	\N
47	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Крыса из нержавеющей стали	\N	11	\N	\N
48	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Вестники Времен	\N	6	\N	Андрей Леонидович Мартьянов (род. 3 сентября 1973, Ленинград) — русский писатель, блогер, переводчик фантастических и исторических произведений. Основные жанры — исторические романы, фэнтези, фантастика.\n
49	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Имя мне - Легион	\N	3	\N	\n
50	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Мир волшебника	\N	2	\N	\N
51	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	История рыжего демона	\N	3	\N	Трилогия создана в соавторстве двумя корифеями мировой фантастики — Робертом Шекли и Роджером Желязны. В неё также входят следующие романы:\n
53	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Хроники Амбера	\N	10	\N	\N
56	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Ойкумена	\N	3	\N	«Ойкумена» — роман в трёх частях харьковских писателей Дмитрия Громова и Олега Ладыженского, пишущих под псевдонимом Генри Лайон Олди, первая проба пера авторов в жанре «космической оперы». Сами авторы называют своё произведение «Космическая симфония».\n
57	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Сказки дедушки-вампира	\N	7	\N	«Дневники вампира» (англ. The Vampire Diaries) — серия книг, написанная 8В в стиле мистики, фэнтези и фантастики. Эта история о девушке  Елене Гилберт, за любовь которой сражаются два брата-вампира Дэймон и Стефан Сальваторе. Изначально была опубликована трилогия «Пробуждение», «Голод» и «Ярость» (1991), но давление читателей заставило Смит написать четвёртый том, «Тёмный альянс» (1992). В 1998 году Смит заявила о новой побочной трилогии, названной «Дневники вампира: Возвращение», продолжая серию с Дэймоном в качестве главного героя. Первая часть трилогии, «Возвращение: Наступление ночи», была выпущена 10 февраля 2009 года. Вторая книга, «Возвращение: Тень души» вышла 16 мая 2010 года.  Полночь» была представлена публике 15 марта 2011 года.\n
29	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Ведьмак	\N	7	http://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Geralt.jpg/272px-Geralt.jpg	«Сага о ведьмаке» (польск. Saga o wiedźminie) — цикл книг польского писателя Анджея Сапковского в жанре фэнтези. \n
9	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Сновидения Ехо	\N	8	\N	Макс Фрай — литературный псевдоним сначала двух писателей, Светланы Мартынчик и Игоря Стёпина, впоследствии Светлана Мартынчик писала самостоятельно[1]. 
10	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Хроники Ехо	\N	8	\N	Макс Фрай — литературный псевдоним сначала двух писателей, Светланы Мартынчик и Игоря Стёпина, впоследствии Светлана Мартынчик писала самостоятельно[1]. 
11	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Волшебник Земноморья	\N	4	\N	\N
30	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Мерлин	\N	5	\N	\N
43	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Майк Такер	\N	1	\N	\N
44	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Дин Кунц	\N	1	\N	\N
62	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Нашествие монголов	\N	3	\N	\N
63	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Проклятые короли	\N	7	\N	«Про́клятые короли́» (фр. Les Rois maudits) — серия из семи исторических романов французского писателя Мориса Дрюона, посвященных истории Франции первой половины XIV века, начиная с 1314 года, когда был окончен процесс над тамплиерами, и заканчивая событиями после битвы при Пуатье.\n
64	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Саксонские хроники	\N	8	\N	После ухода римлян с островов в пятом веке, Британия оказалась раздробленной на множество мелких королевств. Вторжение викингов на Британские острова вызвало волну кровопролития, затяжных войн и разорения.\n
65	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Четыре сестры	\N	5	\N	«Зачаро́ванные» (англ. «Charmed») — серия романов, которые рассказывают о волшебной жизни сестёр-ведьм. В основе лежит одноимённый сериал «Зачарованные». Многие писатели со всего мира пишут рассказы про Зачарованных. Книги имеют свой сюжет и сценарий.\n
69	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Рассказы	\N	7	\N	В случае, если в книге собраны рассказы разных авторов, то принято говорить об альманахе («Меданские вечера», 1880) либо об антологии ранее опубликованных рассказов (The Best American Short Stories, издаётся ежегодно с 1915 года).\n
70	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Игра с цветами смерти	\N	4	\N	\N
71	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Сады Кассандры	\N	2	\N	\N
7	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Сказки старого Вильнюса	\N	7	\N	\N
8	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Лабиринт Ехо	\N	10	\N	\N
58	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Хитроумный Идальго Дон Кихот Ламанчский	\N	2	http://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Miguel_de_Cervantes_%281605%29_El_ingenioso_hidalgo_Don_Quixote_de_la_Mancha.png/255px-Miguel_de_Cervantes_%281605%29_El_ingenioso_hidalgo_Don_Quixote_de_la_Mancha.png	«Хитроу́мный ида́льго Дон Кихо́т Лама́нчский» (исп. El ingenioso hidalgo Don Quijote de la Mancha), часто просто «Дон Кихо́т» — роман испанского писателя Мигеля де Сервантеса Сааведра (1547—1616) о приключениях одноимённого героя. Был опубликован в двух томах. Первый вышел в 1605 году, второй — в 1615 году. Роман задумывался как пародия на рыцарские романы. \n
13	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Повести о Дунке и Эгге	\N	3	\N	\N
15	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Клэй	\N	3	\N	«Клей» — роман Ирвина Уэлша, выпущенный в 2001 году. В романе описывается жизнь шотландских подростков конца XX, начала XXI веков, их взросление, взаимоотношения, взгляды на жизнь. Повествование идёт как от имени разных героев, так и от имени автора. В книге встречаются персонажи, впервые упомянутые в романе  "Кошмары аиста Марабу" и "На игле", в некоторых сценах упоминаются события этих романов.\n
21	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Дивиргент	\N	4	\N	\N
72	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Всеслав и Ева	\N	9	\N	\N
73	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Астра Ельцова	\N	6	\N	\N
33	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Заклинательницы ветров	\N	2	\N	В современном книгоиздании произведения жанровой литературы (детектив, фантастика и фэнтези, любовный роман, юмористическая проза, некоторые поджанры детской литературы и т. д.) выпускаются именно в составе книжных серий. В ряде случаев такие серии являются составной частью вымышленных миров, в которых, помимо книг, выпускают игры (компьютерные или настольные), фильмы или сериалы, а также связанную продукцию. В то же время серийный принцип книгоиздания традиционно широко распространён в области научно-популярной литературы, а также поэзии.\n
35	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Сага о видящих	\N	3	\N	\N
39	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Сумеречные охотники	\N	5	\N	Серия книг стала одной из самых популярных среди подросткового литературного жанра паранормальной романтики или городской фантастики. Однако сама Клэр изначально не собиралась писать серию для подростков, произведение должно было стать фантастическим романом, в котором главные герои — подростки. Когда же издательство изъявило желание увидеть описание процесса взросления персонажей, Кассандра Клэр заявила, что она «хотела рассказать историю о людях, переживающих важнейший этап между юностью и взрослой жизнью, когда каждый шаг определяет, каким человеком ты станешь, а не отражает того, кем ты уже являешься.»[1] Решение представить её романы как подростковую литературу сделало книги Клэр бестселлерами, а Хронику сумеречных охотников — самой популярной среди молодой аудитории.\n
40	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Сьюки Стакхауз	\N	7	\N	\N
74	2021-03-01 11:09:29.416752+00	2021-03-01 11:09:29.416752+00	Эркюль Пуаро	\N	42	http://upload.wikimedia.org/wikipedia/ru/thumb/e/e3/David_Suchet_Poirot.png/274px-David_Suchet_Poirot.png	Эркю́ль Пуаро́ (фр. Hercule Poirot) — литературный персонаж известной английской писательницы Агаты Кристи, бельгийский детектив, главный герой 33 романов, 54 рассказов и 1 пьесы, изданных между 1920 и 1975 годами, и поставленных по ним фильмов, телесериалов, театральных и радиопостановок. В настоящее время серию продолжает другая английская писательница, Софи Ханна, которая на 2019 год опубликовала 3 детективных романа об Эркюле Пуаро.\n
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: kurush
--

COPY public.users (id, created_at, updated_at, name, surname, email, login, password, avatar) FROM stdin;
102	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Раиса	Нарманова	amberwood@hotmail.com	garrettkatelyn	^5WiPLkYBv	https://placekitten.com/963/1000
103	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Алина	Сталпнина	barkererin@hotmail.com	paulmclean	(x7h&Ca+Jk	https://www.lorempixel.com/479/40
104	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Герасим	Кривченков	rmorrow@yahoo.com	lmiller	etaGYc_2!2	https://placekitten.com/384/439
105	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Павел	Бурмин	xmartin@gmail.com	owensholly	#aVW4%)K^6	https://www.lorempixel.com/915/85
106	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Яна	Баландаева	sarah68@gmail.com	paynediana	FSHg9TVk^6	https://placeimg.com/775/995/any
107	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Леонид	Плющов	edwardsjacqueline@hotmail.com	fdiaz	_k#ONwng1Q	https://placekitten.com/584/263
108	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Федор	Подойников	michelle54@yahoo.com	harrisonsherry	Yo6AI^Uk@w	https://placekitten.com/783/523
109	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Аркадий	Крыжевский	carrie15@hotmail.com	thompsonjohn	c@1LIx!8o2	https://placekitten.com/21/689
110	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Николай	Дометин	andersonnorman@yahoo.com	melodywilson	UdkS8yi1_5	https://dummyimage.com/635x434
111	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Ева	Испольнева	portermelissa@hotmail.com	christopherwilliams	cicA2tGhe*	https://www.lorempixel.com/694/581
112	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Антон	Свальнов	ctravis@hotmail.com	rodneybrown	+xQ0#VEjSW	https://dummyimage.com/910x824
113	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Клавдия	Гребанова	davisjoshua@yahoo.com	vmartinez	*p87SK+yxm	https://placekitten.com/560/352
114	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Наталья	Ремескова	ryanmoreno@gmail.com	ofoster	oyFl5Dia#_	https://www.lorempixel.com/12/876
115	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Николай	Клюков	nicholas02@hotmail.com	rwalker	)2TigS5inG	https://dummyimage.com/305x197
116	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Клавдия	Ленковская	ctran@yahoo.com	james00	igu6@8O@_6	https://www.lorempixel.com/549/787
117	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Алёна	Занчева	heather34@yahoo.com	ronaldsmith	N)u6N*ty0P	https://placekitten.com/424/713
118	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Станислав	Мукомолов	stevenbarrera@hotmail.com	andersondylan	&xSS@hftk3	https://placekitten.com/1005/263
119	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Любовь	Маннова	whernandez@gmail.com	courtney91	8Pp7fHe(!$	https://www.lorempixel.com/307/764
120	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Игорь	Шиндиков	jeremytanner@hotmail.com	tadams	CayN6Soz(P	https://placekitten.com/109/895
121	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Алина	Кисвянцева	anthony88@yahoo.com	eric28	_3J*qfB7YM	https://placekitten.com/262/467
122	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Яков	Ларкин	scott49@yahoo.com	blake71	%K$CVSJkV8	https://www.lorempixel.com/990/395
123	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Алина	Синдякова	lromero@yahoo.com	phillipsmiguel	nqH5hD^j@2	https://placekitten.com/650/183
124	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Мария	Рендинова	michaelsandoval@yahoo.com	acostamargaret	R1_XF8ul)P	https://placekitten.com/710/314
125	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Максим	Лодвиков	amber39@yahoo.com	lloyddawn	^K7rPfo731	https://placeimg.com/80/498/any
126	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Вячеслав	Воловичев	acampbell@yahoo.com	wilkinsonalexander	+3zC)TFL_e	https://dummyimage.com/641x794
127	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Евгения	Атаева	christinelindsey@gmail.com	murphyjoshua	5d5NUMlo$i	https://www.lorempixel.com/774/991
128	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Владислав	Дробитов	allenlinda@hotmail.com	john34	^q6I%k!q3O	https://placeimg.com/154/191/any
129	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Артур	Боговаров	sarah11@hotmail.com	jwalker	vi1EGXr)D*	https://www.lorempixel.com/550/563
130	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Алёна	Чурлина	kimberlywilson@hotmail.com	qharvey	@rsE0Nda%y	https://placekitten.com/746/351
131	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Наталья	Дыманова	chriswilliams@yahoo.com	thompsonwalter	Tg)3DEv5f@	https://www.lorempixel.com/204/165
132	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Алина	Варонина	daniellekemp@gmail.com	rachelcook	Bmr7TylFd*	https://www.lorempixel.com/312/237
133	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Александра	Конилова	jennifer94@hotmail.com	sford	h9MfaAPh_S	https://www.lorempixel.com/237/847
134	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Георгий	Алпеев	kristin87@gmail.com	michaelrivera	%0cXhTsqV&	https://www.lorempixel.com/195/466
135	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Юлия	Трансина	pettystacey@hotmail.com	pattondaniel	##J+4fC1%l	https://placekitten.com/612/406
136	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Тарас	Веденский	cameron13@gmail.com	cheryl97	!_cFXoiU6Y	https://placeimg.com/525/574/any
137	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Светлана	Ратанова	cwilson@hotmail.com	derek38	Ia*skNKm^8	https://placeimg.com/792/501/any
138	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Тарас	Атомарин	connorsweeney@hotmail.com	meganmorgan	@iZUJGxX1n	https://placeimg.com/599/730/any
139	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Алёна	Кубичкина	hayslaura@hotmail.com	ischroeder	RLzG0^js_3	https://dummyimage.com/587x572
140	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Илья	Гисов	uwright@gmail.com	hsmith	rfOX)!)r!8	https://placekitten.com/987/105
141	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Юлия	Шадчинова	woodrobin@yahoo.com	manuelthomas	!6tI8urwiZ	https://dummyimage.com/267x319
142	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Вячеслав	Митряшин	christophergomez@hotmail.com	wheelertimothy	k_99+Hsb4w	https://dummyimage.com/350x298
143	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Марина	Апасова	carolyncabrera@yahoo.com	amendoza	rlI9$xFQ_2	https://www.lorempixel.com/440/137
144	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Надежда	Базуникина	john21@gmail.com	austinclark	3kQIdd7f&n	https://placeimg.com/150/888/any
145	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Надежда	Лифинцова	williamsmith@gmail.com	kevinwright	bxrI0M@cK%	https://placekitten.com/505/899
146	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Наталия	Мовсина	carrronnie@gmail.com	colehahn	+I#3Wown58	https://www.lorempixel.com/959/569
147	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Евгений	Швыгин	sking@yahoo.com	markgray	A^00tHEs+f	https://placekitten.com/950/100
148	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Роман	Целинский	mary18@hotmail.com	colinmason	YRc!Q3Aj8&	https://placeimg.com/512/339/any
149	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	София	Гаськова	martinandrew@yahoo.com	nsmith	@oQH4CLU5M	https://placeimg.com/193/372/any
150	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Алла	Орловская	zachary20@gmail.com	christopherhughes	vz!88gDy!T	https://placekitten.com/954/199
151	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Ольга	Копчатова	jenkinsjoshua@hotmail.com	janiceguerra	wp3BqODn)$	https://placekitten.com/898/410
152	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Степан	Босоргин	mary30@yahoo.com	jfischer	0LTz4JUpd^	https://placekitten.com/192/985
153	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Тарас	Цейтлин	brianna77@yahoo.com	smorales	jV2%YN^f3+	https://placekitten.com/578/761
154	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Павел	Горлышщкин	csanchez@yahoo.com	josephallen	(9VXLDfx#n	https://dummyimage.com/358x255
155	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Яна	Ущаповская	katiehiggins@yahoo.com	hardingmatthew	W2&F6CturS	https://placekitten.com/560/708
156	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Роман	Рассомахин	rollinsdavid@gmail.com	wendyandersen	$wYiVP9x32	https://placeimg.com/728/372/any
157	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Леонид	Садовин	calvinphillips@hotmail.com	john36	Y2_REomp)&	https://www.lorempixel.com/304/309
158	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Алёна	Голяшова	carolyn36@gmail.com	carterheather	e(A_8Vb$pe	https://www.lorempixel.com/357/143
159	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Тамара	Бургова	anitaadkins@gmail.com	bonillakathryn	_XEMDNEo15	https://dummyimage.com/808x47
160	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Степан	Мужичков	patelmelissa@yahoo.com	edgar39	4CAJKy%p(2	https://placekitten.com/879/569
161	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Виталий	Тарлавский	pamelamathis@hotmail.com	brownamy	sG*)6EEf7c	https://placekitten.com/450/464
162	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Валентин	Лаврипов	hhorn@hotmail.com	sherri21	%8O)cJ0wJ+	https://placekitten.com/138/84
163	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Валентин	Синепушкин	alyssatodd@yahoo.com	gilbertpaul	XK_1T49p+r	https://placeimg.com/125/525/any
164	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Тарас	Ворганов	ejackson@hotmail.com	kristiconrad	%v+ZN6lMI8	https://www.lorempixel.com/413/594
165	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Екатерина	Фивюшина	bennettkelly@hotmail.com	zachary34	++7J%vChlz	https://placekitten.com/608/787
166	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Аркадий	Балдаев	atkinseugene@gmail.com	evan99	3@7IpO^rPV	https://placeimg.com/520/731/any
167	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Алина	Трацевская	laurachristensen@hotmail.com	jacobhuynh	&D4qF@zn$x	https://dummyimage.com/15x108
168	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Лиза	Олухова	josephrobinson@hotmail.com	patriciathomas	1ek19Aeo&!	https://placekitten.com/766/579
169	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Валерия	Кривцова	rarroyo@gmail.com	richard66	_43Q6XUkZ%	https://dummyimage.com/661x427
170	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Александр	Кокеткин	pattonjoseph@yahoo.com	jacob86	M_3JEcz7G+	https://placeimg.com/54/624/any
171	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Георгий	Меламедов	teresahughes@hotmail.com	stewartkimberly	**CN1Dcdx8	https://dummyimage.com/524x839
172	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Катерина	Дрыбцова	bradyhale@yahoo.com	pvillanueva	&!^Q0$uwcJ	https://www.lorempixel.com/779/613
173	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Алексей	Заплетин	brendalopez@gmail.com	annette23	37JqCJ(*+C	https://dummyimage.com/940x184
174	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Станислав	Менюшин	lawrencecohen@hotmail.com	nwilliams	$524kRrx6a	https://www.lorempixel.com/466/956
175	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Кира	Нарсеева	smithcrystal@yahoo.com	gjones	XvZnFG8q&2	https://www.lorempixel.com/545/366
176	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Кристина	Мурикова	davidsalazar@hotmail.com	alan23	+3P*Qf_sAc	https://placeimg.com/552/103/any
177	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Григорий	Гораткин	cynthianunez@yahoo.com	martincynthia	%!84r^Dk8u	https://dummyimage.com/245x1021
178	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Кирилл	Чикурников	jameswilliams@gmail.com	katherinenelson	%8RUQnp_3Z	https://dummyimage.com/695x61
179	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Вероника	Алафимова	michellewalters@yahoo.com	maryobrien	*M(5K5cCgI	https://placeimg.com/838/823/any
180	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Карина	Тенгизова	jonathanstone@gmail.com	cassandra33	*O1RUSbyXG	https://dummyimage.com/5x379
181	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Карина	Ярцева	mkelly@hotmail.com	whiteheadcrystal	)o6vIxy)%q	https://placekitten.com/835/328
182	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Жанна	Дергаусова	robert79@yahoo.com	randy70	lp6J_44j@_	https://placeimg.com/331/543/any
183	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Георгий	Паражанов	fhanson@gmail.com	alicia83	Z(7MWKMqto	https://placekitten.com/621/348
184	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Вероника	Почикалина	christinegraves@yahoo.com	richard40	!6ZXYC1r5o	https://placeimg.com/672/498/any
185	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Лариса	Сарновская	dianamorales@hotmail.com	amyhenderson	(w0nJ0Es1L	https://placeimg.com/219/330/any
186	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Тамара	Иркалиева	tasha12@hotmail.com	hernandezrobert	%b2qV0@i*u	https://placeimg.com/330/434/any
187	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Алёна	Клявочкина	kristen60@yahoo.com	dmoore	a*5F5n4%SS	https://dummyimage.com/503x139
188	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Леонид	Залыгин	youngdaniel@hotmail.com	kathryn51	!aYmuEs#p0	https://placekitten.com/475/439
189	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Кристина	Лакеева	zpadilla@gmail.com	pfry	)9)ewbikIE	https://www.lorempixel.com/1003/902
190	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Инна	Косарукина	uwhite@yahoo.com	bianca66	d38mDbdR&%	https://dummyimage.com/130x730
191	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Константин	Сачков	thomasward@gmail.com	gabrielpittman	$etZe5dm7a	https://dummyimage.com/398x849
192	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Альберт	Шукуров	regina75@hotmail.com	jessicafuentes	24X@(*pL#q	https://dummyimage.com/351x931
193	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Геннадий	Кусовников	dylan48@yahoo.com	qbarrett	8TRk%I20_Z	https://placekitten.com/66/535
194	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Григорий	Колесихин	frederick54@hotmail.com	rflores	ARV9DQ@w+&	https://dummyimage.com/185x922
195	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Светлана	Кирищева	reyesbryan@gmail.com	traceygriffin	&k4abAhVr&	https://placeimg.com/143/523/any
196	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Вероника	Агафенова	molly35@gmail.com	bryantmichael	S7hApNG7%l	https://dummyimage.com/525x916
197	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Евгения	Фицева	farrellmolly@gmail.com	munozbrenda	V11SsLAV!&	https://placeimg.com/732/68/any
198	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Лиза	Шурканцева	ksmith@gmail.com	michaelgonzalez	)2wZXnEHO6	https://dummyimage.com/148x408
199	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Ксения	Бачурова	reyesrichard@gmail.com	colekaren	R4kOQ&Qm#M	https://placeimg.com/696/150/any
200	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	Вячеслав	Башкунов	blackwelljoshua@hotmail.com	andrewwilson	_C6Q7R^s^N	https://www.lorempixel.com/140/680
201	2021-03-31 15:23:10.519138+00	2021-03-31 15:23:10.519138+00	София	Глутнева	carlamyers@hotmail.com	smithpaige	Vb8JNbn%)F	https://dummyimage.com/817x423
101	2021-03-17 20:14:09.886594+00	2021-03-17 20:14:09.886594+00	Куруш	Казаков	ze17@yandex.ru	kurush	pondoxo	101.jpg
\.


--
-- Name: authors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kurush
--

SELECT pg_catalog.setval('public.authors_id_seq', 132, true);


--
-- Name: books_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kurush
--

SELECT pg_catalog.setval('public.books_id_seq', 911, true);


--
-- Name: publications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kurush
--

SELECT pg_catalog.setval('public.publications_id_seq', 912, true);


--
-- Name: series_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kurush
--

SELECT pg_catalog.setval('public.series_id_seq', 74, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kurush
--

SELECT pg_catalog.setval('public.users_id_seq', 204, true);


--
-- Name: authors authors_pkey; Type: CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.authors
    ADD CONSTRAINT authors_pkey PRIMARY KEY (id);


--
-- Name: books books_pkey; Type: CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.books
    ADD CONSTRAINT books_pkey PRIMARY KEY (id);


--
-- Name: books_series books_series_unique; Type: CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.books_series
    ADD CONSTRAINT books_series_unique UNIQUE (book_id);


--
-- Name: publications publications_isbn13_key; Type: CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.publications
    ADD CONSTRAINT publications_isbn13_key UNIQUE (isbn13);


--
-- Name: publications publications_isbn_key; Type: CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.publications
    ADD CONSTRAINT publications_isbn_key UNIQUE (isbn);


--
-- Name: publications publications_pkey; Type: CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.publications
    ADD CONSTRAINT publications_pkey PRIMARY KEY (id);


--
-- Name: series series_pkey; Type: CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.series
    ADD CONSTRAINT series_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: books_authors books_authors_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.books_authors
    ADD CONSTRAINT books_authors_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.authors(id);


--
-- Name: books_authors books_authors_book_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.books_authors
    ADD CONSTRAINT books_authors_book_id_fkey FOREIGN KEY (book_id) REFERENCES public.books(id);


--
-- Name: books_series books_series_book_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.books_series
    ADD CONSTRAINT books_series_book_id_fkey FOREIGN KEY (book_id) REFERENCES public.books(id);


--
-- Name: books_series books_series_series_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.books_series
    ADD CONSTRAINT books_series_series_id_fkey FOREIGN KEY (series_id) REFERENCES public.series(id);


--
-- Name: book_files publication_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.book_files
    ADD CONSTRAINT publication_fkey FOREIGN KEY (publication_id) REFERENCES public.publications(id);


--
-- Name: publications translation_book_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kurush
--

ALTER TABLE ONLY public.publications
    ADD CONSTRAINT translation_book_fkey FOREIGN KEY (book_id) REFERENCES public.books(id);


--
-- Name: FUNCTION get_author_preview(author_id_param integer); Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON FUNCTION public.get_author_preview(author_id_param integer) TO admin;


--
-- Name: FUNCTION get_book_authors(book_id_param integer); Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON FUNCTION public.get_book_authors(book_id_param integer) TO admin;


--
-- Name: FUNCTION get_book_preview(book_id_param integer); Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON FUNCTION public.get_book_preview(book_id_param integer) TO admin;


--
-- Name: FUNCTION get_books_authors(book_ids_param integer[]); Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON FUNCTION public.get_books_authors(book_ids_param integer[]) TO admin;


--
-- Name: FUNCTION get_series_authors(series_ids_param integer[]); Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON FUNCTION public.get_series_authors(series_ids_param integer[]) TO admin;


--
-- Name: FUNCTION get_series_preview(series_id_param integer); Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON FUNCTION public.get_series_preview(series_id_param integer) TO admin;


--
-- Name: TABLE authors; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON TABLE public.authors TO admin;
GRANT SELECT ON TABLE public.authors TO guest;
GRANT ALL ON TABLE public.authors TO moderator;


--
-- Name: SEQUENCE authors_id_seq; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON SEQUENCE public.authors_id_seq TO admin;


--
-- Name: TABLE book_files; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON TABLE public.book_files TO admin;
GRANT ALL ON TABLE public.book_files TO moderator;
GRANT SELECT ON TABLE public.book_files TO guest;


--
-- Name: TABLE books; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON TABLE public.books TO admin;
GRANT SELECT ON TABLE public.books TO guest;
GRANT ALL ON TABLE public.books TO moderator;


--
-- Name: TABLE books_authors; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON TABLE public.books_authors TO admin;
GRANT SELECT ON TABLE public.books_authors TO guest;
GRANT ALL ON TABLE public.books_authors TO moderator;


--
-- Name: SEQUENCE books_id_seq; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON SEQUENCE public.books_id_seq TO admin;


--
-- Name: TABLE books_series; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON TABLE public.books_series TO admin;
GRANT SELECT ON TABLE public.books_series TO guest;
GRANT ALL ON TABLE public.books_series TO moderator;


--
-- Name: TABLE publications; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON TABLE public.publications TO admin;
GRANT SELECT ON TABLE public.publications TO guest;
GRANT ALL ON TABLE public.publications TO moderator;


--
-- Name: SEQUENCE publications_id_seq; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON SEQUENCE public.publications_id_seq TO admin;


--
-- Name: TABLE series; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON TABLE public.series TO admin;
GRANT SELECT ON TABLE public.series TO guest;
GRANT ALL ON TABLE public.series TO moderator;


--
-- Name: SEQUENCE series_id_seq; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON SEQUENCE public.series_id_seq TO admin;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON TABLE public.users TO admin;
GRANT ALL ON TABLE public.users TO moderator;
GRANT SELECT ON TABLE public.users TO guest;


--
-- Name: SEQUENCE users_id_seq; Type: ACL; Schema: public; Owner: kurush
--

GRANT ALL ON SEQUENCE public.users_id_seq TO admin;


--
-- PostgreSQL database dump complete
--

