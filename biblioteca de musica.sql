create table idioma(
	idi_cod int4 not null,
	idi_idioma varchar(30) not null,
	primary key(idi_cod)
);
create table genero(
	gen_id int4 not null,
	gen_nom varchar(60) not null,
	gen_descripcion varchar(120),
	primary key (gen_id)
); 
create table pais(
	pai_id int4 not null,
	pai_nom varchar(60) not null,
	primary key (pai_id)
);
create table interprete(
	interpre_id int4 not null,
	interpre_nom varchar(60) not null,
	pai_id int4 not null,
	interpre_alias varchar(60),
	primary key (interpre_id),
	foreign key (pai_id) references pais(pai_id)
);
create table album(
	alb_id int4 not null,
	alb_nom varchar(60) not null,
	interpre_id int4 not null,
	alb_descripcion varchar(120),
	primary key (alb_id),
	foreign key (interpre_id) references interprete(interpre_id)
);
create table cancion(
	can_cod serial  not null,
	idi_cod int4 not null,
	alb_id int4 not null,
	gen_id int4 not null,
	can_nombre varchar (60) not null,
	can_duracion time not null,
	primary key (can_cod),
	foreign key (idi_cod) references idioma(idi_cod),
	foreign key (alb_id) references album(alb_id),
	foreign key (gen_id) references genero(gen_id)
);
----Guardar registros en tabla auditoria---------------------

CREATE schema audit;
REVOKE CREATE ON schema audit FROM public;
 
CREATE TABLE audit.auditoria(
    schema_nombre text NOT NULL,
    TABLE_nombre text NOT NULL,
    user_nombre text,
    hora TIMESTAMP WITH TIME zone NOT NULL DEFAULT CURRENT_TIMESTAMP, 
    accion TEXT NOT NULL,
    dato_original text,
    dato_nuevo text
);
 
REVOKE ALL ON audit.auditoria FROM public;
GRANT SELECT ON audit.auditoria TO public;
CREATE INDEX auditoria_schema_table_idx  ON audit.auditoria(((schema_nombre||'.'||TABLE_nombre)::TEXT));
CREATE INDEX auditoria_hora_idx  ON audit.auditoria(hora);
CREATE INDEX auditoria_accion_idx ON audit.auditoria(accion);
CREATE OR REPLACE FUNCTION audit.if_modified_func() RETURNS TRIGGER AS $$
	DECLARE
		v_old_data TEXT;
		v_new_data TEXT;
	BEGIN
    IF (TG_OP = 'UPDATE') THEN
        v_old_data := ROW(OLD.*);
        v_new_data := ROW(NEW.*);
        INSERT INTO audit.auditoria (schema_nombre,table_nombre,user_nombre,accion,dato_original,dato_nuevo) 
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,'UPDATE',v_old_data,v_new_data);
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        v_old_data := ROW(OLD.*);
        INSERT INTO audit.auditoria (schema_nombre,table_nombre,user_nombre,accion,dato_original,dato_nuevo)
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,'DELETE',v_old_data,v_new_data);
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT') THEN
        v_new_data := ROW(NEW.*);
        INSERT INTO audit.auditoria (schema_nombre,table_nombre,user_nombre,accion,dato_original,dato_nuevo)
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,'INSERT',v_old_data,v_new_data);
        RETURN NEW;
    ELSE
        RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
        RETURN NULL;
    END IF;
 
EXCEPTION
    WHEN data_exception THEN
        RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [DATA EXCEPTION] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
        RETURN NULL;
    WHEN unique_violation THEN
        RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [UNIQUE] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
        RETURN NULL;
    WHEN OTHERS THEN
        RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
        RETURN NULL;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit;

CREATE TRIGGER cancion_if_modified_trg AFTER INSERT OR UPDATE OR DELETE ON cancion FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();
CREATE TRIGGER idioma_if_modified_trg AFTER INSERT OR UPDATE OR DELETE ON idioma FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();

-------trigger de ingresar y actualizar en tabla idioma-----------
create or replace function antes_insertar_idioma() returns trigger as
$$
	begin
		if (new.idi_cod is null) then
		     raise exception 'El código del idioma no puede ser nulo';
		end if;
		if (new.idi_idioma is null) then
		     raise exception 'El nombre del idioma no puede ser nulo';
		end if;
		if (exists(select * from idioma where idi_cod=new.idi_cod)) then
		     raise exception 'El codigo del idioma ya esta registrado';
		end if;
		
	return new;
	end;
$$
language 'plpgsql';
create trigger antes_insertar_idioma before insert  or update on idioma for each row execute procedure antes_insertar_idioma();



-------trigger de ingresar y actualizar en tabla genero-----------
create or replace function antes_insertar_genero() returns trigger as
$$
	begin
		if (new.gen_id is null) then
		     raise exception 'El identificador del genero no puede ser nulo';
		end if;
		if (new.gen_nom is null) then
		     raise exception 'El nombre del genero no puede ser nulo';
		end if;
		if (exists(select * from genero where gen_id=new.gen_id)) then
		     raise exception 'El identificador del genero ya esta registrado';
		end if;
		
	return new;
	end;
$$
language 'plpgsql';
create trigger antes_insertar_genero before insert or update on genero for each row execute procedure antes_insertar_genero();


-------trigger de ingresar y actualizar en tabla pais-----------
create or replace function antes_insertar_pais() returns trigger as
$$
	begin
		if (new.pai_id is null) then
		     raise exception 'El identificador del pais no puede ser nulo';
		end if;
		if (new.pai_nom is null) then
		     raise exception 'El nombre del pais no puede ser nulo';
		end if;
		if (exists(select * from pais where pai_id=new.pai_id)) then
		     raise exception 'El identificador del pais ya esta registrado';
		end if;
		
	return new;
	end;
$$
language 'plpgsql';
create trigger antes_insertar_pais before insert or update on pais for each row execute procedure antes_insertar_pais();


-------trigger de ingresar y actualizar en tabla interprete-----------
create or replace function antes_insertar_interprete() returns trigger as
$$
	begin
		if (new.interpre_id is null) then
		     raise exception 'El identificador del interprete no puede ser nulo';
		end if;
		if (new.interpre_nom is null) then
		     raise exception 'El nombre del interprete no puede ser nulo';
		end if;     
		if (new.pai_id is null) then
		     raise exception 'El identificador del pais con el que se encuentra asociado no puede ser nulo';
		end if;
		if (exists(select * from interprete where interpre_id=new.interpre_id)) then
		     raise exception 'El identificador del interprete ya esta registrado';
		end if;
		
	return new;
	end;
$$
language 'plpgsql';
create trigger antes_insertar_interprete before insert or update on interprete for each row execute procedure antes_insertar_interprete();


-------trigger de ingresar y actualizar en tabla album-----------
create or replace function antes_insertar_album() returns trigger as
$$
	begin
		if (new.alb_id is null) then
		     raise exception 'El identificador del album no puede ser nulo';
		end if;
		if (new.alb_nom is null) then
		     raise exception 'El nombre del album no puede ser nulo';
		end if;
		if (exists(select * from album where alb_id=new.alb_id)) then
		     raise exception 'El identificador del album ya esta registrado';
		end if;
		if (new.interpre_id is null) then
		     raise exception 'El identificador del interprete del album no puede ser nulo';
		end if;
		
	return new;
	end;
$$
language 'plpgsql';
create trigger antes_insertar_album before insert or update on album for each row execute procedure antes_insertar_album();


-------trigger de ingresar y actualizar en tabla cancion-----------
create or replace function antes_insertar_cancion() returns trigger as
$$
	begin
		if (new.idi_cod is null) then
		     raise exception 'El codigo del pais no puede ser nulo';
		end if;
		if (new.alb_id is null) then
		     raise exception 'El identificador del album no puede ser nulo';
		end if;
		if (new.gen_id is null) then
		     raise exception 'El identificador del genero no puede ser nulo';
		end if;
		if (new.can_nombre is null) then
		     raise exception 'El nombre de la cancion no puede ser nulo';
		end if;
		if (new.can_duracion is null) then
		     raise exception 'La duracion de la cancion no puede ser nulo';
		end if;
		
	return new;
	end;
$$
language 'plpgsql';
create trigger antes_insertar_cancion before insert or update on cancion for each row execute procedure antes_insertar_cancion();


-------trigger de eliminar en tabla idioma-----------
create or replace function antes_eliminar_idioma() returns trigger as
$$
	begin
		if (exists(select * from cancion where idi_cod=new.idi_cod)) then
		     raise exception 'No se puede eliminar el idioma por que se encuentra asociada con otra tabla ';
		end if;
		
	return new;
	end;
$$
language 'plpgsql';
create trigger antes_eliminar_idioma before delete  on idioma for each row execute procedure antes_eliminar_idioma();


-------trigger de eliminar en tabla genero-----------
create or replace function antes_eliminar_genero() returns trigger as
$$
	begin
		if (exists(select * from cancion where gen_id=new.gen_id)) then
		     raise exception 'No se puede eliminar el genero por que se encuentra asociada con otra tabla ';
		end if;
		
	return new;
	end;
$$
language 'plpgsql';
create trigger antes_eliminar_genero before delete on genero for each row execute procedure antes_eliminar_genero();


-------trigger de eliminar en tabla album-----------
create or replace function antes_eliminar_album() returns trigger as
$$
	begin
		if (exists(select * from cancion where alb_id=new.alb_id)) then
		     raise exception 'No se puede eliminar el album por que se encuentra asociada con otra tabla ';
		end if;
		
	return new;
	end;
$$
language 'plpgsql';
create trigger antes_eliminar_album before delete on album for each row execute procedure antes_eliminar_album();

------------------------------------------------------------------------------------------------------------------------------------------------

insert into idioma(idi_cod,idi_idioma)values (1,'Español');
insert into idioma(idi_cod,idi_idioma)values (2,'Ingles');

insert into genero(gen_id,gen_nom) values(10,'Balada');
insert into genero(gen_id,gen_nom) values(20,'Ranchera');
insert into genero(gen_id,gen_nom) values(30,'pop');
insert into genero(gen_id,gen_nom) values(40,'Vallenato');

insert into pais(pai_id,pai_nom) values (101,'Colombia');
insert into pais(pai_id,pai_nom) values (102,'Venezuela');
insert into pais(pai_id,pai_nom) values (103,'EEUU');
insert into pais(pai_id,pai_nom) values (104,'España');

insert into interprete(interpre_id,interpre_nom,pai_id) values(11,'Felipe Pelaez',101);
insert into interprete(interpre_id,interpre_nom,pai_id) values(22,'Pablo Alboran',104);
insert into interprete(interpre_id,interpre_nom,pai_id) values(33,'Santiago Cruz',101);
insert into interprete(interpre_id,interpre_nom,pai_id,interpre_alias) values(44,'Juan Vásquez',101,'Juanes');
insert into interprete(interpre_id,interpre_nom,pai_id) values(55,'Andres cepeda',101);
insert into interprete(interpre_id,interpre_nom,pai_id) values(66,'Ricardo Montaner',102);
insert into interprete(interpre_id,interpre_nom,pai_id) values(77,'Jesús Alberto Miranda',102);
insert into interprete(interpre_id,interpre_nom,pai_id) values(88,'Michael Jackson‎ ',103);
insert into interprete(interpre_id,interpre_nom,pai_id) values(99,'Bruno Mars',103);

insert into album(alb_id,alb_nom,interpre_id) values(12,'Lo mejor que hay en mi vida',55);
insert into album(alb_id,alb_nom,interpre_id) values(32,'Pablo Alborán',22);
insert into album(alb_id,alb_nom,interpre_id) values(42,'Loco de amor',44);

insert into cancion(idi_cod,alb_id,gen_id,can_nombre,can_duracion) values (1,12,10,'Un ratico','00:03:51');
insert into cancion(idi_cod,alb_id,gen_id,can_nombre,can_duracion) values (1,12,10,'Lo mejor que hay en mi vida','00:04:00');
insert into cancion(idi_cod,alb_id,gen_id,can_nombre,can_duracion) values (1,12,10,'Voy a extrañarte','00:03:20');
insert into cancion(idi_cod,alb_id,gen_id,can_nombre,can_duracion) values (1,32,30,'Lo nuestro','00:05:06');
insert into cancion(idi_cod,alb_id,gen_id,can_nombre,can_duracion) values (1,32,30,'Recuerdame','00:04:57');
insert into cancion(idi_cod,alb_id,gen_id,can_nombre,can_duracion) values (1,42,40,'A Dios le pido','00:03:15');
insert into cancion(idi_cod,alb_id,gen_id,can_nombre,can_duracion) values (1,42,40,'Bonita','00:04:51');

DELETE from cancion
where can_cod=1;
update cancion set can_cod=22
where can_cod=2;
select * from audit.auditoria

