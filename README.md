# ListenApp server code

This is the server part of ListenApp app. Its purpose is to regularly fetch
articles from specified RSS feeds, generate audio chunks for them and save
articles and chunks in the database.

Most requests to ListenApp REST API (in particular requests to ListenApp
resources) require client to authenticate. So let’s say we have Crystal who
downloaded the app and ran it for the first time - in this case the app makes an
anonymous request to the server API:

GET /articles.json HTTP/1.1
Host: talkieapp-staging.herokuapp.com
Accept: application/json

I will also include cURL commands to show how to make these requests from the
terminal:

$ curl -v -H "Accept: application/json" https://talkieapp-staging.herokuapp.com/articles.json

The server will force user to auth by rejecting the request with a 401
(Unauthorized) status code as shown below:

HTTP/1.1 401 Unauthorized

In this case the client will need to present user a sign-up page to allow her to
authenticate. In the first version of the app we will make this transparent to
the user - so, instead of showing the sign-up page, the app will automatically
issue a request to sign up (passing a JSON structure that contains user
information):

POST /users.json HTTP/1.1
Host: talkieapp-staging.herokuapp.com
Accept: application/json
Content-type: application/json

{
  "user": {
    "email": "nicki@gmail.com",
    “name”: “nicki”,
    "password": "starships",
    "password_confirmation": "starships"
  }
}

$ curl -v -H "Accept: application/json" -H "Content-type: application/json" -X POST -d '{"user":{"email":"nicki@gmail.com", "name":"nicki", "password":"starships", "password_confirmation":"starships"}}' https://talkieapp-staging.herokuapp.com/users.json

The server then will try to add this user to the database validating two
constraints: uniqueness of user’s email & uniqueness of user’s device id. If
either of these already exists in the database, the server will issue a 422
(Unprocessable entity) like so:

HTTP/1.1 422 Unprocessable entity

If the validation passes, then a new user object will be created and the server
will respond with 201 (Created):

HTTP/1.1 201 Created 
Location: https://talkieapp-staging.herokuapp.com/users/1

{
  "admin":null,
  "created_at":"2013-05-19T19:12:16Z",
  "email":"nicki@gmail.com",
  "id":1,"name":"nicki",
  "password_digest":"$2a$10$lyo8pBhRMUL.Tc/kbi5TCuU06m3..ZrWBtZ.BesomLYXPG7W6y",
  "remember_token":"ruAMVQcutaHb19SdJFWnYA",
  "updated_at":"2013-05-19T19:12:16Z"
}

This user information will be then used to create a new session (i.e., sign in):

POST /sessions.json HTTP/1.1
Host: talkieapp-staging.herokuapp.com
Accept: application/json
Content-type: application/json

{
  “session”:
    {
      “email”: “nicki@gmail.com”,
      “password”: “starships”
    }
}

$ curl -v -H "Accept: application/json" -H "Content-type: application/json" -X POST -c cookies -d '{"session":{"email":"nicki@gmail.com", "password":"starships"}}' https://talkieapp-staging.herokuapp.com/sessions.json

If authorization succeeds, the response will have the cookie with user’s token
that the client will need to store:

HTTP/1.1 302 Found 
Content-Type: application/json; charset=utf-8
Set-Cookie: remember_token=zYgDdhQd0EXqGZgcf9e1RQ; path=/; expires=Thu, 19-May-2033 19:26:19 GMT; secure

After that the client can make requests to access Talkie resources:

GET /articles.json HTTP/1.1
Host: talkieapp-staging.herokuapp.com
Cookie: remember_token=zYgDdhQd0EXqGZgcf9e1RQ
Accept: application/json

$ curl -v -H "Accept: application/json" -b cookies https://talkieapp-staging.herokuapp.com/articles.json

This will return the list of articles.

If non admin user tries to add an article, they will get 403 (Forbidden):

$ curl -v -H "Accept: application/json" -H "Content-type: application/json" -b cookies -X POST -d '{"article":{"source_id":13, "author":"Nicki Minaj", "title":"Starships", "preview":"Let\u0027s go to the beach, each. Let\u0027s go get away.", "image_url":"image_url", "article_url":"article_url", "body":"They say, what they gonna say? Have a drink, clink, found the bud light. Bad bitches like me, is hard to come by. The patron on, let\u0027s go get it on. The zone on, yes, I\u0027m in the zone. Is it two, three? Leave a good tip. I\u0027mma blow off my money and don\u0027t give two shits", "preview_chunks":3}}' https://talkieapp-staging.herokuapp.com/articles.json