# This is an auto-generated Django model module.
# You'll have to do the following manually to clean this up:
#   * Rearrange models' order
#   * Make sure each model has one field with primary_key=True
#   * Make sure each ForeignKey and OneToOneField has `on_delete` set to the desired behavior
#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table
# Feel free to rename the models, but don't rename db_table values or field names.
from django.db import models


class Authors(models.Model):
    id = models.IntegerField(primary_key=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    name = models.CharField(max_length=256)
    birthdate = models.DateField(blank=True, null=True)
    country = models.CharField(max_length=64, blank=True, null=True)
    photo = models.CharField(max_length=1000, blank=True, null=True)
    description = models.CharField(max_length=1000, blank=True, null=True)

    def __str__(self):
        return self.name

    class Meta:
        managed = False
        db_table = 'authors'


class BookFiles(models.Model):
    publication = models.ForeignKey('Publications', models.DO_NOTHING)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    file_path = models.CharField(max_length=256)
    file_type = models.CharField(max_length=16, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'book_files'


class Books(models.Model):
    id = models.IntegerField(primary_key=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    title = models.CharField(max_length=256)
    skin_image = models.CharField(max_length=1000, blank=True, null=True)
    description = models.CharField(max_length=1000, blank=True, null=True)
    genres = models.TextField(blank=True, null=True)  # This field type is a guess.

    def __str__(self):
        return self.title

    class Meta:
        managed = False
        db_table = 'books'


class BooksAuthors(models.Model):
    author = models.ForeignKey(Authors, models.DO_NOTHING, blank=True, null=True)
    book = models.ForeignKey(Books, models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'books_authors'


class BooksSeries(models.Model):
    series = models.ForeignKey('Series', models.DO_NOTHING, blank=True, null=True)
    book = models.OneToOneField(Books, models.DO_NOTHING, blank=True, null=True)
    book_number = models.SmallIntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'books_series'


class Publications(models.Model):
    id = models.IntegerField(primary_key=True)
    book = models.ForeignKey(Books, models.DO_NOTHING)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    publication_year = models.SmallIntegerField(blank=True, null=True)
    language_code = models.CharField(max_length=2, blank=True, null=True)
    isbn = models.BigIntegerField(unique=True, blank=True, null=True)
    isbn13 = models.BigIntegerField(unique=True, blank=True, null=True)
    info = models.JSONField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'publications'


class Series(models.Model):
    id = models.IntegerField(primary_key=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    title = models.CharField(max_length=256)
    is_finished = models.BooleanField(blank=True, null=True)
    books_count = models.SmallIntegerField(blank=True, null=True)
    skin_image = models.CharField(max_length=1000, blank=True, null=True)
    description = models.CharField(max_length=1000, blank=True, null=True)

    def __str__(self):
        return self.title

    class Meta:
        managed = False
        db_table = 'series'


class Users(models.Model):
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    name = models.CharField(max_length=256, blank=True, null=True)
    surname = models.CharField(max_length=256, blank=True, null=True)
    email = models.CharField(max_length=64, blank=True, null=True)
    login = models.CharField(max_length=64, blank=True, null=True)
    password = models.CharField(max_length=64, blank=True, null=True)
    avatar = models.CharField(max_length=1000, blank=True, null=True)

    def __str__(self):
        return self.name + ' ' + self.surname

    class Meta:
        managed = False
        db_table = 'users'
