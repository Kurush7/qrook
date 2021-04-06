from django.contrib import admin

from .models import *

admin.site.register(Books)
admin.site.register(Authors)
admin.site.register(Series)
admin.site.register(Publications)
admin.site.register(Users)
admin.site.register(BookFiles)
admin.site.register(BooksAuthors)
admin.site.register(BooksSeries)


# Register your models here.
