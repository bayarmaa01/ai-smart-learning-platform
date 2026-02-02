from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route("/ai", methods=["POST"])
def ai():
    data = request.json
    question = data.get("question")

    if "монгол" in question.lower():
        return jsonify({"answer": "Сайн байна уу! Би AI багш."})
    return jsonify({"answer": "Hello! I am your AI tutor."})

app.run(host="0.0.0.0", port=6000)
