
DSAA 4040 Course Project Handout
Cloud Computing & Big Data Systems
Instructor: Guoming Tang
Spring 2026 | HKUST(GZ)

Updated on Apr. 17, 2026

1. Project Overview
The course project is a group project designed to help you apply key ideas from cloud computing and big data systems in a concrete setting.

Each group may choose one project from one of the following two tracks:

Research-Oriented Projects
Engineering-Oriented Projects
Note: You are allowed to design and propose your own project topic, but it needs the confirmation of instructor.

The two tracks have different goals:

Research-oriented projects focus on asking a clear systems question, designing experiments, collecting evidence, and drawing conclusions.
Engineering-oriented projects focus on designing, implementing, deploying, and demonstrating a working system.
You should choose the track that best matches your team’s interests and strengths.

2. Team Size
Recommended team size: 1–2 students per group (recommended); groups of 3 students are allowed with justification.
3. Recommended Environments
To keep the project focused on systems understanding rather than heavy infrastructure setup, lightweight environments are fully acceptable.

For Kubernetes-based projects
You may use:

Minikube
Docker Desktop Kubernetes
K3s
For Spark-based projects
You may use:

PySpark in local mode
Single-node Spark standalone mode
Note: You will not receive extra credit simply for using a more complicated environment.

4. Deliverables
Each group must submit the following:

Source code / configuration files
Project report (PDF)
Proposal/Presentation slides/Demo video
README with setup and reproduction instructions
5. Report Format
For Research-Oriented Projects
Your report should be written in a mini-paper style and include:

Introduction
Research Question / Hypothesis
Methodology / Experimental Setup
Results
Discussion
Conclusion
References
For Engineering-Oriented Projects
Your report should be written in a technical report style and include:

Problem Statement
System Design
Implementation
Deployment / Demo
Evaluation or Testing
Limitations and Future Work
References
6. Task Levels
Each project contains three levels of requirements:

Basic
Minimum requirements. Every group must complete these.
Standard
Expected level for a strong project.
Advanced / Bonus
Optional challenges for stronger groups. These help distinguish top projects, but quality matters more than quantity.
Note: Completing more bonus tasks does not automatically guarantee a higher grade.
A smaller project done well is better than a larger project done poorly.

Part B. Engineering-Oriented Projects

E3. Design and Implement a Multi-Tenant Kubernetes Lab Platform with RBAC and Resource Isolation
Goal
Design a small Kubernetes-based lab platform for multiple users or teams, with access control and basic resource isolation.

Suggested Environment
Minikube or K3s
Simulated users/roles are acceptable
No enterprise authentication system is required
Background
Shared cloud platforms require basic tenant isolation and permission control. This project asks you to design a simplified multi-tenant Kubernetes environment suitable for a teaching lab or student project platform.

Basic Requirements
Define at least three user roles, such as:

admin
developer
viewer
Configure:

namespaces
Role / RoleBinding or ClusterRole / ClusterRoleBinding
Demonstrate different access permissions for different roles.

Provide documentation for how the platform is organized.

Standard Requirements
Add ResourceQuota or LimitRange.
Design the platform as if each student team had its own namespace.
Include a simple onboarding or usage guide.
Explain your security and isolation design clearly.
Advanced
Demonstrate how your design prevents misuse or accidental damage.
Add NetworkPolicy or finer-grained permissions.
Build simple automation scripts or a lightweight portal.
Discuss scalability and limitations of your design.
Expected Engineering Focus
Multi-tenancy, isolation, RBAC, and platform-style Kubernetes design.

7. Project Difficulty Guide
To help you choose an appropriate project, we provide the following difficulty classification:

Level 1 (Moderate)
R2: Data Format vs Spark Performance
E4. Cloud-Native Message Board on Kubernetes
Level 2 (Moderate–Challenging)
R1: Auto-Scaling on Kubernetes
E1: Cloud-Native Online Bookstore
E2: Streaming Log Analytics Pipeline
R4. Resource Sensitivity of Kubernetes Workloads
Level 3 (Challenging)
R3: Resource Allocation and Fairness in Kubernetes
E3: Multi-Tenant Kubernetes Platform
Recommendation
If your goal is to complete a solid and stable project, choose a Level 1–2 project.
If your goal is to aim for top grades (A/A+), consider a Level 3 project, but be prepared for higher uncertainty.
8. Grading Rubric
Research-Oriented Projects
Problem formulation: 15%
Methodology / experiment design: 25%
Implementation correctness: 20%
Analysis and insight: 25%
Proposal/Presentation/Report&Demo: 15%
Engineering-Oriented Projects
System design: 20%
Implementation quality: 25%
Deployment / demo: 20%
Completeness and robustness: 20%
Proposal/Presentation/Report&Demo: 15%

9. Milestones
Milestone 1: Topic Selection (Due: Apr. 19, 2026)
Each group must submit a short proposal (1-2 page):

Recommended Template: https://share.note.sx/pi9puh00#o3qTV0whjf3soGZD76lLiFLjU6BrC6RlxC9xuDDaDAk
Milestone 2: Progress Demonstration (May. 7, 2026)
Each group must present their progress:

presentation
demo video / live demo (optional)
Milestone 3: Final Submission (Tentative: May. 21, 2026)
Each group must submit:

code/configuration

report

demo video

10. Academic Integrity and Use of AI Tools
You may use AI tools such as ChatGPT, Claude, or Copilot to help with:

brainstorming,
debugging,
explaining errors,
writing boilerplate code,
polishing documentation.
However:

You must understand and verify all submitted work.
You must disclose major AI usage in an appendix or short note.
Blindly copying AI-generated code or text without verification is not acceptable.
Your project will be evaluated based on your understanding, not on how much code you can generate.
11. Project Advice
Choose a topic that matches your team’s strength.

Choose a research-oriented project if your team enjoys experiments, comparisons, and analysis.
Choose an engineering-oriented project if your team enjoys building and demonstrating working systems.
A well-scoped, clearly executed project is better than an over-ambitious one.

Good luck :