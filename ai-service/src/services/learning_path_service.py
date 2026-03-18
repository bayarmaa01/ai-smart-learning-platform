"""
Learning Path Service
Generates personalized learning paths based on user goals, current level, and preferences.
"""

import logging
from typing import List, Dict, Optional
from datetime import datetime

logger = logging.getLogger(__name__)


def get_learning_path(
    user_goal: str,
    current_level: str = "beginner",
    language_preference: str = "en",
    time_commitment: str = "medium",  # low, medium, high
    focus_areas: Optional[List[str]] = None,
) -> Dict:
    """
    Generate a personalized learning path based on user goals and preferences.

    Args:
        user_goal: User's learning goal (e.g., "web development", "data science")
        current_level: Current skill level (beginner, intermediate, advanced)
        language_preference: 'en' or 'mn'
        time_commitment: low (2-3 hrs/week), medium (5-7 hrs/week), high (10+ hrs/week)
        focus_areas: Specific areas to focus on

    Returns:
        Personalized learning path with courses, timeline, and milestones
    """

    is_mn = language_preference == "mn"

    # Define learning paths for different goals
    learning_paths = {
        "web development": {
            "beginner": {
                "courses": [
                    {
                        "title": "HTML & CSS Fundamentals"
                        if not is_mn
                        else "HTML & CSS Үндэс",
                        "duration_weeks": 4,
                        "difficulty": "beginner",
                        "description": "Learn the building blocks of web pages"
                        if not is_mn
                        else "Вэб хуудасны үндэс суурь судлах",
                        "topics": [
                            "HTML5",
                            "CSS3",
                            "Responsive Design",
                            "Flexbox",
                            "Grid",
                        ],
                    },
                    {
                        "title": "JavaScript Programming"
                        if not is_mn
                        else "JavaScript Програмчлал",
                        "duration_weeks": 6,
                        "difficulty": "beginner",
                        "description": "Master JavaScript for interactive web applications"
                        if not is_mn
                        else "Интерактив вэб аппликацадад JavaScript-г эзэмших",
                        "topics": [
                            "Variables",
                            "Functions",
                            "DOM Manipulation",
                            "Events",
                            "Async JS",
                        ],
                    },
                    {
                        "title": "React.js Modern Development"
                        if not is_mn
                        else "React.js Орчин Үеийн Хөгжүүлэлт",
                        "duration_weeks": 8,
                        "difficulty": "intermediate",
                        "description": "Build modern web applications with React"
                        if not is_mn
                        else "React-р орчин үеийн вэб аппликац бүтээх",
                        "topics": [
                            "Components",
                            "State Management",
                            "Hooks",
                            "Routing",
                            "Performance",
                        ],
                    },
                    {
                        "title": "Node.js & Express Backend"
                        if not is_mn
                        else "Node.js & Express Backend",
                        "duration_weeks": 6,
                        "difficulty": "intermediate",
                        "description": "Build scalable backend applications"
                        if not is_mn
                        else "Өргөтгөх чадвартай backend аппликац бүтээх",
                        "topics": [
                            "Node.js",
                            "Express",
                            "REST APIs",
                            "Database Integration",
                            "Authentication",
                        ],
                    },
                ],
                "total_duration_weeks": 24,
                "milestones": [
                    "Build your first website"
                    if not is_mn
                    else "Анхны вэбсайтаа бүтээх",
                    "Create interactive JavaScript applications"
                    if not is_mn
                    else "Интерактив JavaScript аппликац үүсгэх",
                    "Develop React applications"
                    if not is_mn
                    else "React аппликац хөгжүүлэх",
                    "Build full-stack applications"
                    if not is_mn
                    else "Full-stack аппликац бүтээх",
                ],
            },
            "intermediate": {
                "courses": [
                    {
                        "title": "Advanced React & TypeScript"
                        if not is_mn
                        else "Дэвшилтэт React & TypeScript",
                        "duration_weeks": 6,
                        "difficulty": "advanced",
                        "description": "Master React with TypeScript and advanced patterns"
                        if not is_mn
                        else "TypeScript-р React-г мэргэжлэх",
                        "topics": [
                            "TypeScript",
                            "Advanced Patterns",
                            "Performance",
                            "Testing",
                            "Architecture",
                        ],
                    },
                    {
                        "title": "Microservices Architecture"
                        if not is_mn
                        else "Микросервис Архитектур",
                        "duration_weeks": 8,
                        "difficulty": "advanced",
                        "description": "Design and build microservices"
                        if not is_mn
                        else "Микросервис дизайн ба бүтээл",
                        "topics": [
                            "Microservices",
                            "Docker",
                            "API Gateway",
                            "Service Mesh",
                            "Monitoring",
                        ],
                    },
                    {
                        "title": "Cloud Deployment & DevOps"
                        if not is_mn
                        else "Клауд Deploy & DevOps",
                        "duration_weeks": 6,
                        "difficulty": "advanced",
                        "description": "Deploy applications to the cloud"
                        if not is_mn
                        else "Аппликацыг клауд руу deploy хийх",
                        "topics": [
                            "AWS/Azure/GCP",
                            "CI/CD",
                            "Infrastructure as Code",
                            "Monitoring",
                            "Security",
                        ],
                    },
                ],
                "total_duration_weeks": 20,
                "milestones": [
                    "Master TypeScript with React"
                    if not is_mn
                    else "TypeScript-р React-г эзэмших",
                    "Build microservices architecture"
                    if not is_mn
                    else "Микросервис архитектур бүтээх",
                    "Deploy to production cloud"
                    if not is_mn
                    else "Бүтээгдэхүүний клауд руу deploy хийх",
                ],
            },
        },
        "data science": {
            "beginner": {
                "courses": [
                    {
                        "title": "Python Programming for Data Science"
                        if not is_mn
                        else "Өгөгдлийн Шинжлэх Ухаанд Python Програмчлал",
                        "duration_weeks": 6,
                        "difficulty": "beginner",
                        "description": "Learn Python for data analysis"
                        if not is_mn
                        else "Өгөгдлийн шинжилгээнд Python сурах",
                        "topics": [
                            "Python Basics",
                            "NumPy",
                            "Pandas",
                            "Data Cleaning",
                            "Visualization",
                        ],
                    },
                    {
                        "title": "Statistics & Probability"
                        if not is_mn
                        else "Статистик & Магадлал",
                        "duration_weeks": 4,
                        "difficulty": "beginner",
                        "description": "Master statistical concepts"
                        if not is_mn
                        else "Статистикийн үндсэн ойлголт",
                        "topics": [
                            "Descriptive Statistics",
                            "Probability",
                            "Distributions",
                            "Hypothesis Testing",
                        ],
                    },
                    {
                        "title": "Machine Learning Fundamentals"
                        if not is_mn
                        else "Машин Сургалтын Үндэс",
                        "duration_weeks": 8,
                        "difficulty": "intermediate",
                        "description": "Introduction to machine learning algorithms"
                        if not is_mn
                        else "Машин сургалтын алгоритмын танилцуулга",
                        "topics": [
                            "Linear Regression",
                            "Classification",
                            "Clustering",
                            "Model Evaluation",
                        ],
                    },
                    {
                        "title": "Deep Learning with TensorFlow"
                        if not is_mn
                        else "TensorFlow-р Гүнзгий Суралт",
                        "duration_weeks": 10,
                        "difficulty": "advanced",
                        "description": "Build neural networks with TensorFlow"
                        if not is_mn
                        else "TensorFlow-р нейрон сүлжээ бүтээх",
                        "topics": [
                            "Neural Networks",
                            "CNN",
                            "RNN",
                            "Transfer Learning",
                            "Deployment",
                        ],
                    },
                ],
                "total_duration_weeks": 28,
                "milestones": [
                    "Analyze datasets with Python"
                    if not is_mn
                    else "Python-р өгөгдлийн багцыг шинжлэх",
                    "Build ML models" if not is_mn else "ML загвар бүтээх",
                    "Create deep learning models"
                    if not is_mn
                    else "Гүнзгий сургалтын загвар үүсгэх",
                    "Deploy ML models"
                    if not is_mn
                    else "ML загварууд deploy хийх",
                ],
            }
        },
        "devops": {
            "beginner": {
                "courses": [
                    {
                        "title": "Linux Fundamentals"
                        if not is_mn
                        else "Linux Үндэс",
                        "duration_weeks": 4,
                        "difficulty": "beginner",
                        "description": "Master Linux command line and system administration"
                        if not is_mn
                        else "Linux команд мөр ба системийн удирдлагыг эзэмших",
                        "topics": [
                            "Command Line",
                            "File System",
                            "Processes",
                            "Shell Scripting",
                            "System Administration",
                        ],
                    },
                    {
                        "title": "Docker & Containerization"
                        if not is_mn
                        else "Docker & Контейнерчлэл",
                        "duration_weeks": 6,
                        "difficulty": "intermediate",
                        "description": "Containerize applications with Docker"
                        if not is_mn
                        else "Docker-р аппликацыг контейнерчлэх",
                        "topics": [
                            "Docker Basics",
                            "Dockerfile",
                            "Docker Compose",
                            "Volumes",
                            "Networking",
                        ],
                    },
                    {
                        "title": "Kubernetes Orchestration"
                        if not is_mn
                        else "Kubernetes Оркестраци",
                        "duration_weeks": 8,
                        "difficulty": "advanced",
                        "description": "Manage containerized applications at scale"
                        if not is_mn
                        else "Контейнерчилсэн аппликацыг том хэмжээнд удирдах",
                        "topics": [
                            "Kubernetes Basics",
                            "Pods & Services",
                            "Deployments",
                            "Scaling",
                            "Monitoring",
                        ],
                    },
                ],
                "total_duration_weeks": 18,
                "milestones": [
                    "Navigate Linux systems efficiently"
                    if not is_mn
                    else "Linux системд үр дүнтэй ажиллах",
                    "Containerize applications"
                    if not is_mn
                    else "Аппликацыг контейнерчлэх",
                    "Manage production Kubernetes clusters"
                    if not is_mn
                    else "Бүтээгдэхүүний Kubernetes кластер удирдах",
                ],
            }
        },
    }

    # Normalize user goal
    goal_key = user_goal.lower()
    if goal_key not in learning_paths:
        # Find closest match
        for key in learning_paths:
            if key in goal_key or goal_key in key:
                goal_key = key
                break
        else:
            goal_key = "web development"  # default

    # Get appropriate path
    if (
        goal_key not in learning_paths
        or current_level not in learning_paths[goal_key]
    ):
        goal_key = "web development"
        current_level = "beginner"

    path_data = learning_paths[goal_key][current_level]

    # Adjust based on time commitment
    time_multipliers = {
        "low": 1.5,  # Slower pace
        "medium": 1.0,  # Normal pace
        "high": 0.7,  # Faster pace
    }

    multiplier = time_multipliers.get(time_commitment, 1.0)

    # Adjust course durations
    adjusted_courses = []
    for course in path_data["courses"]:
        adjusted_course = course.copy()
        adjusted_course["duration_weeks"] = max(
            2, int(course["duration_weeks"] * multiplier)
        )
        adjusted_courses.append(adjusted_course)

    # Calculate total adjusted duration
    total_duration = sum(
        course["duration_weeks"] for course in adjusted_courses
    )

    # Generate timeline
    current_date = datetime.now()
    timeline = []
    cumulative_weeks = 0

    for course in adjusted_courses:
        start_date = current_date + datetime.timedelta(weeks=cumulative_weeks)
        end_date = current_date + datetime.timedelta(
            weeks=cumulative_weeks + course["duration_weeks"]
        )

        timeline.append(
            {
                "course": course["title"],
                "start_date": start_date.strftime("%Y-%m-%d"),
                "end_date": end_date.strftime("%Y-%m-%d"),
                "duration_weeks": course["duration_weeks"],
            }
        )

        cumulative_weeks += course["duration_weeks"]

    # Generate recommendations
    recommendations = []
    if current_level == "beginner":
        recommendations.append(
            "Start with fundamentals and build strong foundations"
            if not is_mn
            else "Үндсэн суурь эхлээд бэхжүүлэх"
        )
    elif current_level == "intermediate":
        recommendations.append(
            "Focus on practical projects and real-world applications"
            if not is_mn
            else "Практик төсөл болон бодит ерөнхий аппликацид анхаарах"
        )
    else:
        recommendations.append(
            "Explore advanced topics and specialization areas"
            if not is_mn
            else "Дэвшилтэт сэдэв болон мэргэжилсэн чиглэл судлах"
        )

    # Add time commitment specific advice
    if time_commitment == "low":
        recommendations.append(
            "Consistent daily practice is key - even 30 minutes helps"
            if not is_mn
            else "Тогтмолтой өдөр тутмын дасгал хэлбэр чухал - түүчээх 30 минут ч тусална"
        )
    elif time_commitment == "high":
        recommendations.append(
            "Balance intensity with adequate rest to avoid burnout"
            if not is_mn
            else "Шахам их хурдтайгаар тэнцвэлж, хэтэрхий ачааллаас зайлсах"
        )

    learning_path = {
        "goal": user_goal,
        "current_level": current_level,
        "language_preference": language_preference,
        "time_commitment": time_commitment,
        "total_duration_weeks": total_duration,
        "estimated_completion_date": (
            current_date + datetime.timedelta(weeks=total_duration)
        ).strftime("%Y-%m-%d"),
        "courses": adjusted_courses,
        "milestones": path_data["milestones"],
        "timeline": timeline,
        "recommendations": recommendations,
        "created_at": datetime.now().isoformat(),
    }

    logger.info(
        f"Generated learning path for goal: {user_goal}, level: {current_level}, duration: {total_duration} weeks"
    )

    return learning_path


def get_skill_assessment(
    user_skills: List[str], target_role: str, language: str = "en"
) -> Dict:
    """
    Assess user skills against target role requirements.

    Args:
        user_skills: List of user's current skills
        target_role: Target role (e.g., "full stack developer", "data scientist")
        language: 'en' or 'mn'

    Returns:
        Skill gap analysis and recommendations
    """

    is_mn = language == "mn"

    # Define role requirements
    role_requirements = {
        "full stack developer": {
            "required_skills": [
                "HTML",
                "CSS",
                "JavaScript",
                "React",
                "Node.js",
                "Database",
                "Git",
                "REST APIs",
                "Authentication",
                "Testing",
            ],
            "nice_to_have": [
                "TypeScript",
                "Docker",
                "AWS",
                "GraphQL",
                "CI/CD",
                "MongoDB",
            ],
        },
        "data scientist": {
            "required_skills": [
                "Python",
                "Statistics",
                "Machine Learning",
                "Data Analysis",
                "SQL",
                "Data Visualization",
                "Pandas",
                "NumPy",
                "Jupyter",
            ],
            "nice_to_have": [
                "Deep Learning",
                "TensorFlow",
                "Spark",
                "Big Data",
                "AWS",
                "Git",
            ],
        },
        "devops engineer": {
            "required_skills": [
                "Linux",
                "Docker",
                "Kubernetes",
                "CI/CD",
                "Cloud Platforms",
                "Monitoring",
                "Networking",
                "Security",
                "Automation",
            ],
            "nice_to_have": [
                "Terraform",
                "Ansible",
                "Python",
                "Go",
                "System Design",
                "Git",
            ],
        },
    }

    # Normalize target role
    role_key = target_role.lower()
    if role_key not in role_requirements:
        for key in role_requirements:
            if key in role_key or role_key in key:
                role_key = key
                break
        else:
            role_key = "full stack developer"

    requirements = role_requirements[role_key]

    # Assess skills
    user_skills_lower = [skill.lower() for skill in user_skills]
    required_skills_lower = [
        skill.lower() for skill in requirements["required_skills"]
    ]
    nice_to_have_lower = [
        skill.lower() for skill in requirements["nice_to_have"]
    ]

    # Find skill gaps
    missing_required = [
        skill
        for skill in requirements["required_skills"]
        if skill.lower() not in user_skills_lower
    ]

    missing_nice_to_have = [
        skill
        for skill in requirements["nice_to_have"]
        if skill.lower() not in user_skills_lower
    ]

    existing_required = [
        skill
        for skill in requirements["required_skills"]
        if skill.lower() in user_skills_lower
    ]

    existing_nice_to_have = [
        skill
        for skill in requirements["nice_to_have"]
        if skill.lower() in user_skills_lower
    ]

    # Calculate readiness score
    required_score = len(existing_required) / len(
        requirements["required_skills"]
    )
    nice_to_have_score = len(existing_nice_to_have) / len(
        requirements["nice_to_have"]
    )
    overall_score = (required_score * 0.7) + (nice_to_have_score * 0.3)

    # Generate recommendations
    if overall_score >= 0.8:
        readiness = "ready" if not is_mn else "бэлэн"
        message = (
            "You have the required skills for this role!"
            if not is_mn
            else "Танд энэ албан тушаалд шаардлагатай чадварууд байна!"
        )
    elif overall_score >= 0.5:
        readiness = "almost_ready" if not is_mn else "бараг бэлэн"
        message = (
            "You're close! Focus on the missing required skills."
            if not is_mn
            else "Та ойрхоо байна! Дутагдсан шаардлагатай чадварууд дээр анхаарна уу."
        )
    else:
        readiness = "needs_work" if not is_mn else "ажил хэрэгтэй"
        message = (
            "You need to develop more required skills first."
            if not is_mn
            else "Та эхлээл илүү шаардлагатай чадваруудыг хөгжүүлэх хэрэгтэй."
        )

    assessment = {
        "target_role": target_role,
        "readiness_level": readiness,
        "overall_score": round(overall_score, 2),
        "required_score": round(required_score, 2),
        "nice_to_have_score": round(nice_to_have_score, 2),
        "existing_required_skills": existing_required,
        "existing_nice_to_have_skills": existing_nice_to_have,
        "missing_required_skills": missing_required,
        "missing_nice_to_have_skills": missing_nice_to_have,
        "message": message,
        "recommendations": [
            f"Focus on learning: {', '.join(missing_required[:3])}"
            if not is_mn
            else f"Эдгээрийг сурахад анхаарах: {', '.join(missing_required[:3])}"
        ],
        "estimated_time_to_ready": f"{len(missing_required) * 4} weeks"
        if missing_required
        else "0 weeks",
        "language": language,
        "assessed_at": datetime.now().isoformat(),
    }

    logger.info(
        f"Skill assessment completed for role: {target_role}, readiness: {readiness}"
    )

    return assessment
