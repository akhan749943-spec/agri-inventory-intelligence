## **🌾 Agri-Supply Inventory Intelligence**

##### &#x09;(***Dead Stock Detection \& Reorder Optimization)***



###### **📌 Project Overview**

An agricultural supply company managing seeds, fertilizers, pesticides, and farm equipment across multiple warehouses is losing lakhs annually due to dead stock, poor reorder timing, and seasonal demand mismatches. This project transforms raw PostgreSQL inventory data into an interactive Power BI dashboard that enables smarter stocking, inventory clearance, and timely reordering decisions.



###### **🎯 Business Problem**

* **The Challenge**: The business had **₹3.4 Crores** of capital suffocating on warehouse shelves, misdiagnosed as a general "overstocking" issue rather than a targeted inventory allocation failure.
* **The Insight**: The company didn't have *too much stock*; it had *the wrong stock*. Capital was trapped in zero-velocity items while fast-moving inventory constantly risked stocking out.
* **The Solution**: Developed an automated risk-analysis and reorder intelligence system to pinpoint dead inventory by region and supplier, providing a clear roadmap to liquidate stagnant assets and reinvest in high-velocity products.



###### **🛠️ Tech Stack**

PostgreSQL | Python (Pandas, SQLAlchemy) | Power BI | DAX





###### **🗄️ Database Schema**



Here is the Database Schema for my project:



```mermaid

erDiagram

&#x20;   products ||--o{ inventory : "stored in"

&#x20;   erDiagram

&#x20;   products ||--o{ inventory : "stored in"

&#x20;   products ||--o{ sales\_transactions : "sold in"

&#x20;   warehouses ||--o{ inventory : "holds"

&#x20;   warehouses ||--o{ sales\_transactions : "fulfills"

&#x20;   suppliers ||--o{ sales\_transactions : "supplies"



&#x20;   products {

&#x20;       serial product\_id PK

&#x20;       varchar(150) product\_name

&#x20;       varchar(50) category

&#x20;       varchar(50) sub\_category

&#x20;       numeric(10\_2) unit\_price

&#x20;       varchar(20) unit\_of\_measure

&#x20;       integer shelf\_life\_months

&#x20;       integer reorder\_point

&#x20;       integer max\_stock\_level

&#x20;   }



&#x20;   warehouses {

&#x20;       serial warehouse\_id PK

&#x20;       varchar(100) warehouse\_name

&#x20;       varchar(50) city

&#x20;       varchar(50) region

&#x20;       integer capacity\_units

&#x20;   }



&#x20;   inventory {

&#x20;       serial inventory\_id PK

&#x20;       integer product\_id FK

&#x20;       integer warehouse\_id FK

&#x20;       integer current\_stock

&#x20;       date last\_restocked\_date

&#x20;       date expiry\_date

&#x20;   }



&#x20;   suppliers {

&#x20;       serial supplier\_id PK

&#x20;       varchar(100) supplier\_name

&#x20;       varchar(50) city

&#x20;       varchar(50) region

&#x20;       integer lead\_time\_days

&#x20;       numeric(10\_2) reliability\_score

&#x20;   }



&#x20;   sales\_transactions {

&#x20;       serial transaction\_id PK

&#x20;       integer product\_id FK

&#x20;       integer warehouse\_id FK

&#x20;       integer supplier\_id FK

&#x20;       date sale\_date

&#x20;       integer quantity\_sold

&#x20;       numeric(10\_2) unit\_price\_sold

&#x20;       numeric(10\_2) total\_amount

&#x20;       varchar(30) customer\_type

&#x20;   }





5 relational tables: products, warehouses, suppliers, inventory, sales\_transactions



###### **📊 Dashboard Pages**

!\[Page 1 Dashboard](visuals/Page\_01\_Inventory\_Overview.png)

!\[Page 2 Dashboard](visuals/Page\_02\_Dead\_Stock \& Risk\_Analysis.png)

!\[Page 3 Dashboard](visuals/Page\_03\_Reorder\_Intelligence.png)



###### **🔑 Top Insights**

* The "Wrong Stock" Problem: The company thought they simply bought "too much inventory." The data proved the real issue: they bought the wrong inventory. We had cash tied up in items that never sell, while popular items were constantly running out.
* The ₹3.4 Cr Cash Trap: I found that exactly ₹3.4 Crores is currently sitting on warehouse shelves as "Dead Stock" (meaning these items haven't had a single sale in the last 90 days).
* The 1-to-34 Risk Ratio: For every ₹1 stuck in dead stock, there is between ₹26 to ₹34 of potential revenue at risk because our fast-selling items are dangerously low on inventory.
* Rescuing Cash (Liquidation): If the company sells off the dead stock at a 40% discount just to clear warehouse space, they can immediately recover around ₹1.36 Crores in cash to reinvest.
* Spotting Problem Suppliers: The dashboard highlights exactly which suppliers are sending us the most dead stock. This gives the procurement team a clear list of who they need to call to renegotiate or cancel orders.
* Preventing Lost Sales: The Reorder Intelligence page flagged several high-demand products that had less than 3 days of inventory left, giving the team an exact checklist of what to buy today before they run out.
* Sales Speed vs. Stock Volume: The scatter plot proved a massive mismatch: our best-selling items were chronically under-stocked, while our worst-selling items were taking up the most physical warehouse space.
* Fixing Regional Imbalances: The data showed that some central warehouses were hoarding extra stock, while smaller regional branches were completely sold out of the exact same items.



###### **💡 Key Recommendations**

* **Executive Summary**:

  * Currently, we have ₹3.4 Crores tied up in dead stock that is actively draining ₹1.1 Crores a year in warehouse storage fees. By selling this dead stock at a 40% discount, we will take a one-time loss but instantly recover ₹2.05 Crores in liquid cash. We can then use just a small fraction of that cash (₹23.3 Lakhs) to completely restock our critically low items, leaving the company with a massive net positive cash position of over ₹1.8 Crores.
* **Recommendation**:

  * I recommend we immediately liquidate the dead stock at the 40% discount to stop the ₹1.1 Crore annual storage bleed, and use the cash we get back to fully fund our critical inventory reorders today.



###### **📁 Project Structure**

📁agri-inventory-intelligence/

│

├── sql/

│   ├── day\_01-02\_data\_preparation.sql

│   ├── day\_03\_data\_verification.sql

│   ├── day\_04\_inventory\_health.sql

│   ├── day\_05\_dead\_stock\_analysis.sql

│   ├── day\_06\_sales\_velocity.sql

│   └── day\_07\_reorder\_intelligence.sql

│   └── day\_08\_financial\_impact.sql

│

├── jupyter\_notebook/

│   ├── day\_09\_python\_postgres\_connection.ipynb

│   └── day\_10\_feature\_engineering.ipynb

│

├── data/

│   ├── warehouses.csv

│   ├── suppliers.csv

│   ├── products.csv

│   ├── inventory.csv

│   ├── sales\_transactions.csv

│   └── agri\_inventory\_master\_analysis.csv

│

├── dashboard/

│   └── Agri\_Inventory\_Dashboard.pbix

│

├── visuals/

│   ├── page01\_inventory\_overview.png

│   ├── page02\_dead\_stock \& risk\_analysis.png

│   ├── page03\_reorder\_intelligence.png

│   └── schema\_diagram.png  (see Step 3)

│

└── README.md



**👤 Author**

**Asif Khan | Data Analyst**

\[LinkedIn] | \[Email]

