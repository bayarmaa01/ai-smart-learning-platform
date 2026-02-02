from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/api")  # <-- make sure it's exactly /api
def api():
    return jsonify({"message": "Backend API working"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
